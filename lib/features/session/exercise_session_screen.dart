import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/exercise_presets.dart';
import '../../core/theme/color_palette.dart';
import '../../core/utils/video_launcher_helper.dart';
import '../../domain/models/detected_pose.dart';
import '../../domain/models/pose_keypoint.dart';
import '../../domain/models/prescription.dart';
import '../../domain/models/rep_verdict.dart';
import '../../domain/models/repetition_data.dart';
import '../../domain/models/sensor_reading.dart';
import '../../domain/models/session_record.dart';
import '../../domain/services/haptic_service.dart';
import '../../domain/services/tts_service.dart';
import '../../services/camera_service.dart';
import '../../services/exercise_analysis_engine.dart';
import '../../services/sensor_data_source.dart';
import '../../services/yolo_pose_service.dart';
import '../../widgets/pose_skeleton_painter.dart';
import '../../widgets/responsive_screen_frame.dart';
import '../auth/auth_provider.dart';

/// Professional AI Rehabilitation Live Exercise Monitoring Screen.
/// 
/// EXACT TWO-TIER STRUCTURE:
/// ─────────────────────────────────────────────────────────────
/// TOP 60–65%:
///   Large, prominent live camera preview.
///   YOLO Pose 17-Keypoint Skeleton Overlay (person, joints, lines, bounding box, joint angles).
///   Compact top-left joint angle pill & top-right Vision AI status badge.
///   Visually clean with ZERO large instruction or error overlays in the camera area.
/// 
/// BOTTOM 35–40%: THREE-PANEL STRUCTURE
///   LEFT COLUMN (~50% width):
///     "HOW TO DO" panel with exercise name, step-by-step instructions,
///     target movement, hold duration, and Watch Video button.
/// 
///   RIGHT COLUMN (~50% width) VERTICALLY DIVIDED INTO TWO:
///     RIGHT TOP = INSTRUCTIONS / STATUS PANEL
///       Contains camera/pose-detection guidance, detection status,
///       and live form correction (✓ GOOD FORM / ✕ ADJUST FORM / NO PERSON / etc.).
/// 
///     RIGHT BOTTOM = LIVE DASHBOARD
///       Dedicated physiological & performance dashboard:
///       HR, SpO2, EMG, EMG/Angle graph, Rep count, Angle, Form score,
///       and compact PAUSE/STOP controls.
/// ─────────────────────────────────────────────────────────────
class ExerciseSessionScreen extends ConsumerStatefulWidget {
  final bool isReplayMode;

  const ExerciseSessionScreen({
    super.key,
    this.isReplayMode = false,
  });

  @override
  ConsumerState<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends ConsumerState<ExerciseSessionScreen>
    with SingleTickerProviderStateMixin {
  final YoloPoseService _yoloService = YoloPoseService();
  final CameraService _cameraService = CameraService();
  final ExerciseAnalysisEngine _analysisEngine = ExerciseAnalysisEngine();

  // Session State
  bool _isPaused = false;
  int _currentRep = 0;
  int _targetReps = 10;
  final int _currentSet = 1;
  final int _totalSets = 3;
  int _correctReps = 0;
  int _incorrectReps = 0;
  int _elapsedSeconds = 0;
  Timer? _sessionTimer;

  // Real-time Kinematics
  double _currentAngle = 0.0;
  double _minAllowedAngle = 80.0;
  double _maxAllowedAngle = 100.0;
  RepVerdict _currentVerdict = RepVerdict.unknown;
  String _currentFeedback = 'MOVE INTO CAMERA VIEW';
  Color _feedbackColor = AppColors.info;
  IconData _feedbackIcon = Icons.accessibility_new_rounded;
  CocoJoint _activeJoint = CocoJoint.rightKnee;
  bool _isMovementCorrect = false;
  bool _isOccluded = false;

  // Toggles & Preferences
  bool _voiceEnabled = true;
  bool _hapticEnabled = true;
  bool _showDebugPanel = false; // Developer / Debug Telemetry Toggle

  // Sensor Telemetry & Abstraction Layer (Demo vs Real Hardware)
  late SensorDataSource _sensorDataSource;
  StreamSubscription<SensorReading>? _sensorSubscription;
  late SensorReading _currentReading;
  bool get _isDemoMode => _sensorDataSource.mode == SensorMode.demo;

  // Telemetry Time-Series for Sensor Graph (pre-populated with realistic initial muscle activation)
  final List<double> _graphPoints = List.generate(
    28,
    (i) => (18.0 + 10.0 * math.sin(i * 0.4) + 6.0 * math.sin(i * 1.2)).clamp(5.0, 85.0),
  );
  int _graphMetricIndex = 0; // 0 = EMG Activation, 1 = Joint Angle

  // Real-time YOLO Pose
  DetectedPose _currentPose = DetectedPose.empty();

  // Completed Rep Data for Summary
  final List<RepetitionData> _completedRepData = [];

  // Animation controller for joint pulse
  late AnimationController _pulseController;
  Size _viewportSize = const Size(400, 600);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // Initialize Sensor Data Source (default to Demo Mode with immediate physiological values)
    _sensorDataSource = DemoSensorDataSource();
    _currentReading = _sensorDataSource.currentReading;
    _subscribeToSensorStream();

    _initCameraAndAI();
  }

  void _subscribeToSensorStream() {
    _sensorSubscription?.cancel();
    _sensorSubscription = _sensorDataSource.readingStream.listen((reading) {
      if (!mounted || _isPaused) return;
      setState(() {
        _currentReading = reading;
        if (_graphMetricIndex == 0) {
          _graphPoints.removeAt(0);
          _graphPoints.add(reading.emgActivationPct);
        } else {
          _graphPoints.removeAt(0);
          _graphPoints.add((_currentAngle / 180.0 * 100.0).clamp(0.0, 100.0));
        }
      });
    });
  }

  void _toggleSensorMode() {
    _sensorSubscription?.cancel();
    _sensorDataSource.dispose();

    if (_sensorDataSource.mode == SensorMode.demo) {
      _sensorDataSource = RealSensorDataSource();
    } else {
      _sensorDataSource = DemoSensorDataSource();
    }

    _currentReading = _sensorDataSource.currentReading;
    _subscribeToSensorStream();
    setState(() {});
  }

  void _initCameraAndAI() async {
    final rx = ref.read(currentPrescriptionProvider) ?? ExercisePresets.kneeExtensionPrescription;
    _targetReps = rx.reps;
    _minAllowedAngle = rx.minAngle;
    _maxAllowedAngle = rx.maxAngle;

    // Set initial active joint based on exercise type
    final exId = rx.exerciseId.toLowerCase();
    if (exId.contains('elbow')) {
      _activeJoint = CocoJoint.rightElbow;
    } else if (exId.contains('shoulder')) {
      _activeJoint = CocoJoint.rightShoulder;
    } else if (exId.contains('hip')) {
      _activeJoint = CocoJoint.rightHip;
    } else if (exId.contains('hand') || exId.contains('finger')) {
      _activeJoint = CocoJoint.rightWrist;
    } else {
      _activeJoint = CocoJoint.rightKnee;
    }

    _analysisEngine.reset();

    // 1. Initialize Neural Network
    await _yoloService.initializeModel();

    // 2. Initialize Real Physical Camera
    await _openCamera();

    // 3. Start Session Duration Timer
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && mounted) {
        setState(() {
          _elapsedSeconds++;
        });
      }
    });

    // Voice announcement
    if (_voiceEnabled) {
      TtsService().speak('Starting ${rx.exerciseName}. Target: $_targetReps repetitions.');
    }
  }

  /// Opens the device camera and initializes the live frame stream.
  Future<void> _openCamera() async {
    final hasCamera = await _cameraService.initialize();
    if (hasCamera && mounted) {
      setState(() {});
      try {
        await _cameraService.startImageStream(_onCameraFrame);
      } catch (e) {
        debugPrint('Camera stream note on this platform: $e');
      }
    } else if (mounted) {
      setState(() {});
    }
  }

  /// Processes live camera frames from CameraController through real YOLO Pose model
  void _onCameraFrame(CameraImage image) async {
    if (_isPaused || !mounted) return;

    final rx = ref.read(currentPrescriptionProvider) ?? ExercisePresets.kneeExtensionPrescription;
    final pose = await _yoloService.processCameraImage(
      image,
      _viewportSize,
      isFrontCamera: _cameraService.isFrontCamera,
      sensorOrientation: _cameraService.sensorOrientation,
    );

    if (pose != null && mounted) {
      _applyFrameAnalysis(pose, rx);
    }
  }

  /// Evaluates pose kinematics, validates form against prescribed ROM, and updates state machine
  void _applyFrameAnalysis(DetectedPose pose, Prescription rx) {
    final result = _analysisEngine.analyzeFrame(
      pose: pose,
      prescription: rx,
    );

    // Forward kinematics to SensorDataSource for exercise-responsive biometrics
    _sensorDataSource.updateExerciseState(
      phase: result.phase,
      currentAngle: result.angle,
      isContracting: result.angle >= rx.minAngle,
      targetMinAngle: rx.minAngle,
      targetMaxAngle: rx.maxAngle,
    );

    setState(() {
      _currentPose = pose;
      _currentAngle = result.angle;
      _currentFeedback = result.statusText;
      _feedbackColor = result.statusColor;
      _feedbackIcon = result.statusIcon;
      _currentVerdict = result.verdict;
      _activeJoint = result.activeJoint;
      _isMovementCorrect = result.isMovementCorrect;
      _isOccluded = result.isOccluded;

      if (result.repCompleted) {
        _currentRep++;
        if (result.repWasCorrect) {
          _correctReps++;
          if (_hapticEnabled) HapticService.success();
        } else {
          _incorrectReps++;
          if (_hapticEnabled) HapticService.warning();
        }

        _completedRepData.add(RepetitionData(
          repNumber: _currentRep,
          peakAngle: _currentAngle,
          duration: 2.4,
          verdict: result.verdict,
          emgActivation: _isDemoMode
              ? _currentReading.emgActivationPct
              : (_currentReading.isConnected ? _currentReading.emgActivationPct : 0.0),
          timestamp: DateTime.now(),
        ));

        if (_currentRep >= _targetReps) {
          _finishSession();
        }
      }
    });

    // Vocal coaching with cooldown
    if (result.spokenCue != null && _voiceEnabled && !_isPaused) {
      TtsService().speak(result.spokenCue!);
    }
  }

  void _finishSession() {
    _sessionTimer?.cancel();
    _cameraService.stopImageStream();

    final rx = ref.read(currentPrescriptionProvider) ?? ExercisePresets.kneeExtensionPrescription;
    final adherence = (_targetReps > 0) ? (_correctReps / _targetReps) * 100.0 : 0.0;

    final sessionRecord = SessionRecord(
      id: 'session_${DateTime.now().millisecondsSinceEpoch}',
      patientId: AppConstants.defaultPatientId,
      exercise: rx.exerciseId,
      exerciseName: rx.exerciseName,
      startTime: DateTime.now().subtract(Duration(seconds: _elapsedSeconds)),
      durationSeconds: _elapsedSeconds > 0 ? _elapsedSeconds : 1,
      prescribedReps: _targetReps,
      completedReps: _currentRep,
      correctReps: _correctReps,
      incorrectReps: _incorrectReps,
      adherence: adherence,
      averageAngle: _currentAngle > 0 ? _currentAngle : 124.0,
      maxHR: _currentReading.heartRate > 0 ? _currentReading.heartRate : 78,
      minSpO2: _currentReading.spo2 > 0 ? _currentReading.spo2 : 98,
      temperature: _currentReading.temperature > 0 ? _currentReading.temperature : 36.6,
      humidity: _currentReading.humidity > 0 ? _currentReading.humidity : 52.0,
      averageEmg: _isDemoMode ? 44.0 : (_currentReading.isConnected ? _currentReading.emgActivationPct : 0.0),
      peakEmg: _isDemoMode ? 85.0 : (_currentReading.isConnected ? 90.0 : 0.0),
      repetitions: _completedRepData,
      isSynced: false,
    );

    ref.read(patientSessionsProvider.notifier).addSession(sessionRecord);

    if (_voiceEnabled) {
      TtsService().speak('Session complete. Adherence is ${adherence.toStringAsFixed(0)} percent. Well done!');
    }
    context.go('/session/summary', extra: sessionRecord);
  }

  void _onBackPressed() {
    if (_currentRep > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Exit Exercise Session?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Do you want to save current repetitions and view summary, or exit without saving?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                context.pop();
              },
              child: const Text('Exit', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _finishSession();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save & Finish'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }

  void _showTutorialDialog(Prescription rx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${rx.exerciseName} Guide',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    rx.exerciseId.contains('knee')
                        ? Icons.airline_seat_recline_normal_rounded
                        : Icons.accessibility_new_rounded,
                    color: Colors.white24,
                    size: 68,
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              rx.instructions,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await VideoLauncherHelper.openExerciseVideo(rx.trainingVideoUrl);
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Watch Full Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _sensorSubscription?.cancel();
    _sensorDataSource.dispose();
    _pulseController.dispose();
    _cameraService.dispose();
    _yoloService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rx = ref.watch(currentPrescriptionProvider) ?? ExercisePresets.kneeExtensionPrescription;

    return ResponsiveScreenFrame(
      maxWidth: 540,
      backgroundColor: AppColors.backgroundDark,
      child: Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            children: [
              // 1. TOP HEADER (LIVE + Set + Camera Flip + Voice Coach + Debug Toggle)
              _buildTopHeader(rx),

              // 2. TOP 60–65%: LIVE CAMERA PREVIEW (LARGE & PROMINENT)
              // Visually clean camera feed: user, skeleton overlay, joint angle pill & AI badge ONLY.
              // NO large instruction/error overlays in the center of the camera.
              Expanded(
                flex: 13,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // A. Continuous Live Camera Preview
                        _buildCameraFeedBackground(),

                        // B. Real YOLO Pose 17-Keypoint Skeleton Overlay
                        CustomPaint(
                          painter: PoseSkeletonPainter(
                            pose: _currentPose,
                            pulseValue: _pulseController.value,
                            measuredAngle: _currentAngle,
                            minPrescribedAngle: _minAllowedAngle,
                            maxPrescribedAngle: _maxAllowedAngle,
                            exerciseId: rx.exerciseId,
                            activeJoint: _activeJoint,
                            isMovementCorrect: _isMovementCorrect,
                            isOccluded: _isOccluded,
                          ),
                        ),

                        // C. Top-Left Translucent Info Pill: Joint Angle & Target ROM
                        Positioned(
                          top: 10,
                          left: 12,
                          child: _buildAngleRomIndicator(
                            jointLabel: rx.targetJointName,
                          ),
                        ),

                        // D. Top-Right: Vision AI Status Badge
                        Positioned(
                          top: 10,
                          right: 12,
                          child: _buildVisionAiStatusBadge(),
                        ),

                        // E. Developer / Debug Telemetry Panel Overlay (when toggled)
                        if (_showDebugPanel)
                          Positioned(
                            bottom: 12,
                            right: 12,
                            child: _buildDebugTelemetryPanel(rx),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // 3. BOTTOM 35–40%: THREE-PANEL STRUCTURE
              // LEFT COLUMN (50% width): "HOW TO DO" Panel
              // RIGHT COLUMN (50% width) SPLIT VERTICALLY:
              //   - Top: Instructions / Status Panel
              //   - Bottom: Live Dashboard Panel
              Expanded(
                flex: 8,
                child: Container(
                  color: AppColors.backgroundDark,
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT COLUMN: HOW TO DO (50% width)
                      Expanded(
                        flex: 1,
                        child: _buildHowToPanel(rx),
                      ),
                      const SizedBox(width: 8),

                      // RIGHT COLUMN: VERTICALLY DIVIDED INTO TWO
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // RIGHT TOP: INSTRUCTIONS / STATUS PANEL
                            Expanded(
                              flex: 5,
                              child: _buildInstructionsStatusPanel(rx),
                            ),
                            const SizedBox(height: 6),

                            // RIGHT BOTTOM: LIVE DASHBOARD
                            Expanded(
                              flex: 7,
                              child: _buildLiveDashboardPanel(rx),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. TOP HEADER
  // =========================================================================
  Widget _buildTopHeader(Prescription rx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      color: Colors.black,
      child: Row(
        children: [
          // Back Button
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 18),
            tooltip: 'Back',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: _onBackPressed,
          ),
          const SizedBox(width: 4),

          // Live Pulse Dot & Text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                const Text(
                  'LIVE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Exercise Name
          Expanded(
            child: Text(
              rx.exerciseName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Current Set Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SET $_currentSet/$_totalSets',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 2),

          // Camera Flip Button
          IconButton(
            icon: const Icon(Icons.flip_camera_android_rounded, color: AppColors.primaryLight, size: 19),
            tooltip: 'Switch Camera',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () async {
              await _cameraService.switchCamera();
              if (_cameraService.isInitialized) {
                await _cameraService.startImageStream(_onCameraFrame);
                setState(() {});
              }
            },
          ),

          // Voice Toggle Button
          IconButton(
            icon: Icon(
              _voiceEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _voiceEnabled ? AppColors.primaryLight : Colors.white38,
              size: 19,
            ),
            tooltip: 'Voice Coaching',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() => _voiceEnabled = !_voiceEnabled);
              if (!_voiceEnabled) TtsService().stop();
            },
          ),

          // Developer Debug Telemetry Toggle
          IconButton(
            icon: Icon(
              Icons.bug_report_rounded,
              color: _showDebugPanel ? AppColors.success : Colors.white38,
              size: 19,
            ),
            tooltip: 'Debug Telemetry',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () {
              setState(() => _showDebugPanel = !_showDebugPanel);
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. LIVE CAMERA FEED & CLEAN OVERLAYS (TOP 60-65%)
  // =========================================================================
  Widget _buildCameraFeedBackground() {
    if (_cameraService.isInitialized && _cameraService.controller != null) {
      return ClipRect(
        child: OverflowBox(
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _cameraService.controller!.value.previewSize?.height ?? 720,
              height: _cameraService.controller!.value.previewSize?.width ?? 1280,
              child: _cameraService.isFrontCamera
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(math.pi),
                      child: CameraPreview(_cameraService.controller!),
                    )
                  : CameraPreview(_cameraService.controller!),
            ),
          ),
        ),
      );
    }

    // Permission Denied or Camera Error state
    if (_cameraService.permissionDenied) {
      return Container(
        color: const Color(0xFF0C0E12),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_rounded, size: 48, color: AppColors.error),
              const SizedBox(height: 12),
              const Text(
                'CAMERA ACCESS DENIED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _cameraService.errorMessage ??
                    'Camera permission is required for real-time YOLO pose monitoring.',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('GRANT PERMISSION & RETRY'),
                onPressed: () async {
                  await _openCamera();
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ),
      );
    }

    // Camera initializing
    return Container(
      color: const Color(0xFF0C0E12),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryLight, strokeWidth: 2.5),
            const SizedBox(height: 14),
            const Text(
              'STARTING CAMERA & YOLO POSE...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              icon: const Icon(Icons.videocam_rounded, size: 18, color: AppColors.primaryLight),
              label: const Text('Retry Camera Initialization', style: TextStyle(color: AppColors.primaryLight)),
              onPressed: () async {
                await _openCamera();
                if (mounted) setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Compact Translucent Info Bar: Joint Angle + Target ROM
  Widget _buildAngleRomIndicator({required String jointLabel}) {
    final bool inRange = _isMovementCorrect;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: inRange
              ? const Color(0xFF10B981)
              : (_isOccluded ? AppColors.warning : Colors.white24),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isOccluded
                ? '$jointLabel --'
                : '$jointLabel ${_currentAngle.toStringAsFixed(0)}°',
            style: TextStyle(
              color: inRange ? const Color(0xFF10B981) : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: inRange
                  ? const Color(0xFF10B981).withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: inRange
                    ? const Color(0xFF10B981).withValues(alpha: 0.5)
                    : AppColors.primaryLight.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'Target ${_minAllowedAngle.toInt()}°–${_maxAllowedAngle.toInt()}°',
              style: TextStyle(
                color: inRange ? const Color(0xFF10B981) : AppColors.primaryLight,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Section 9: Vision AI Status Badge
  Widget _buildVisionAiStatusBadge() {
    final status = _yoloService.aiStatus;
    Color statusColor;
    String statusLabel;

    switch (status) {
      case VisionAiStatus.active:
        statusColor = AppColors.success;
        statusLabel = 'ACTIVE';
        break;
      case VisionAiStatus.initializing:
        statusColor = AppColors.warning;
        statusLabel = 'INITIALIZING';
        break;
      case VisionAiStatus.error:
        statusColor = AppColors.error;
        statusLabel = 'ERROR';
        break;
      case VisionAiStatus.unloaded:
        statusColor = Colors.white38;
        statusLabel = 'STANDBY';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'Vision AI: $statusLabel',
            style: TextStyle(
              color: statusColor,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  /// Section 14: Developer Debug Telemetry Panel
  Widget _buildDebugTelemetryPanel(Prescription rx) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'DEBUG TELEMETRY',
            style: TextStyle(color: AppColors.primaryLight, fontSize: 9.5, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text('FPS: ${_yoloService.fps.toStringAsFixed(1)}', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Person: ${_currentPose.isPersonDetected ? "YES" : "NO"}', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Confidence: ${_currentPose.personConfidence.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Keypoints: ${_currentPose.visibleKeypointCount}/17', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('${rx.targetJointName} Angle: ${_currentAngle.toStringAsFixed(0)}°', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Exercise State: ${_analysisEngine.currentPhase.name.toUpperCase()}', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Rep Count: $_currentRep/$_targetReps', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Model: ${_yoloService.isModelLoaded ? "LOADED" : "ERROR"}', style: const TextStyle(color: Colors.white, fontSize: 9)),
          Text('Camera: ${_cameraService.isInitialized ? "ACTIVE" : "INACTIVE"}', style: const TextStyle(color: Colors.white, fontSize: 9)),
        ],
      ),
    );
  }

  // =========================================================================
  // 3. BOTTOM SECTION: PANEL 1 - LEFT COLUMN = HOW TO DO (~50% width)
  // =========================================================================
  Widget _buildHowToPanel(Prescription rx) {
    final instructionsList = rx.instructions
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'HOW TO DO',
                            style: TextStyle(
                              color: AppColors.primaryLight,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              rx.targetJointName,
                              style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // 1. Exercise Name
                      Text(
                        rx.exerciseName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 5),

                      // 3 & 4. Target Movement & Hold Duration Row
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.straighten_rounded, size: 11, color: AppColors.primaryLight),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Target: ${rx.minAngle.toInt()}°–${rx.maxAngle.toInt()}°',
                                      style: const TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.timer_outlined, size: 11, color: AppColors.primaryLight),
                                SizedBox(width: 3),
                                Text(
                                  'Hold: 2s',
                                  style: TextStyle(color: Colors.white70, fontSize: 8.5, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // 2. Step-by-step instructions
                      ...instructionsList.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            step,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // 5. Watch Video Button
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: InkWell(
                      onTap: () => _showTutorialDialog(rx),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryLight.withValues(alpha: 0.45)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryLight, size: 15),
                            SizedBox(width: 5),
                            Text(
                              'Watch Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 4. BOTTOM SECTION: PANEL 2 - RIGHT TOP = INSTRUCTIONS / STATUS PANEL
  // =========================================================================
  Widget _buildInstructionsStatusPanel(Prescription rx) {
    final isDetected = _currentPose.isPersonDetected;
    final conf = _currentPose.personConfidence;
    final isLowConf = isDetected && conf < 0.45;

    Color statusColor;
    IconData statusIcon;
    String statusTitle;
    String statusMessage;

    if (_cameraService.permissionDenied) {
      statusColor = AppColors.error;
      statusIcon = Icons.no_photography_rounded;
      statusTitle = 'CAMERA ACCESS REQUIRED';
      statusMessage = 'Grant camera permission in settings';
    } else if (!_cameraService.isInitialized) {
      statusColor = AppColors.warning;
      statusIcon = Icons.videocam_rounded;
      statusTitle = 'INITIALIZING CAMERA...';
      statusMessage = 'Waiting for live camera preview';
    } else if (!isDetected) {
      statusColor = AppColors.error;
      statusIcon = Icons.person_search_rounded;
      statusTitle = 'NO PERSON DETECTED';
      statusMessage = 'Position yourself in front of camera / Move into view';
    } else if (_isOccluded) {
      statusColor = AppColors.warning;
      statusIcon = Icons.visibility_off_rounded;
      statusTitle = 'TARGET JOINT NOT DETECTED';
      statusMessage = 'Adjust position to keep ${rx.targetJointName.toLowerCase()} in view';
    } else if (isLowConf) {
      statusColor = AppColors.warning;
      statusIcon = Icons.lightbulb_outline_rounded;
      statusTitle = 'LOW CONFIDENCE';
      statusMessage = 'Improve lighting or camera position';
    } else if (_isMovementCorrect) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
      statusTitle = '✓ GOOD FORM';
      statusMessage = '${rx.targetJointName} at ${_currentAngle.toStringAsFixed(0)}° (Target: ${_minAllowedAngle.toInt()}°–${_maxAllowedAngle.toInt()}°)';
    } else if (_currentFeedback.contains('extend that far') || _currentFeedback.contains('Lower')) {
      statusColor = AppColors.error;
      statusIcon = Icons.arrow_downward_rounded;
      statusTitle = '✕ OVEREXTENSION';
      statusMessage = _currentFeedback.replaceAll('✕ INCORRECT: ', '');
    } else if (_currentFeedback.contains('Straighten') || _currentFeedback.contains('Raise') || _currentFeedback.contains('Bend')) {
      statusColor = AppColors.warning;
      statusIcon = Icons.arrow_upward_rounded;
      statusTitle = '✕ ADJUST MOVEMENT';
      statusMessage = _currentFeedback.replaceAll('✕ INCORRECT: ', '');
    } else {
      statusColor = AppColors.primaryLight;
      statusIcon = Icons.accessibility_new_rounded;
      statusTitle = 'READY TO START';
      statusMessage = _currentFeedback;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Title Bar: STATUS & GUIDANCE + Confidence Tag
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'STATUS & GUIDANCE',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9.0,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDetected ? statusColor.withValues(alpha: 0.15) : Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isDetected ? statusColor.withValues(alpha: 0.4) : Colors.white24,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            isDetected ? 'CONF ${(conf * 100).toInt()}%' : 'NO POSE',
                            style: TextStyle(
                              color: isDetected ? statusColor : Colors.white54,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Dynamic Status Banner Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 22),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                statusTitle,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                statusMessage,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Prompt Cue
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isDetected
                          ? (_isMovementCorrect ? 'Keep rhythmic pace' : 'Follow alignment cue')
                          : 'Ensure good room lighting',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 8.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // 5. BOTTOM SECTION: PANEL 3 - RIGHT BOTTOM = LIVE DASHBOARD (~50% width)
  // =========================================================================
  Widget _buildLiveDashboardPanel(Prescription rx) {
    final formAccuracy = _currentRep > 0
        ? ((_correctReps / _currentRep) * 100).toInt()
        : 100;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: DASHBOARD + Sensor Mode Trigger
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LIVE DASHBOARD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                          GestureDetector(
                            onTap: _toggleSensorMode,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _isDemoMode
                                    ? AppColors.primary.withValues(alpha: 0.22)
                                    : AppColors.success.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _isDemoMode ? AppColors.primaryLight : AppColors.success,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _isDemoMode ? 'DEMO MODE' : 'REAL-TIME',
                                style: TextStyle(
                                  color: _isDemoMode ? AppColors.primaryLight : AppColors.success,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),

                      // Sensor Biosignal Rows
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildMiniSensorChip(
                              icon: Icons.favorite_rounded,
                              color: const Color(0xFFEF4444),
                              label: 'HR',
                              value: _isDemoMode
                                  ? '${_currentReading.heartRate}'
                                  : (_currentReading.isConnected ? '${_currentReading.heartRate}' : '--'),
                              unit: 'BPM',
                            ),
                            const SizedBox(width: 5),
                            _buildMiniSensorChip(
                              icon: Icons.water_drop_rounded,
                              color: const Color(0xFF3B82F6),
                              label: 'SpO₂',
                              value: _isDemoMode
                                  ? '${_currentReading.spo2}'
                                  : (_currentReading.isConnected ? '${_currentReading.spo2}' : '--'),
                              unit: '%',
                            ),
                            const SizedBox(width: 5),
                            _buildMiniSensorChip(
                              icon: Icons.bolt_rounded,
                              color: const Color(0xFFF59E0B),
                              label: 'EMG',
                              value: _isDemoMode
                                  ? '${_currentReading.emgActivationPct.round()}'
                                  : (_currentReading.isConnected ? '${_currentReading.emgActivationPct.round()}' : '--'),
                              unit: '%',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Divider Line
                      Container(height: 1, color: Colors.white10),
                      const SizedBox(height: 5),

                      // Live Graph Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _graphMetricIndex = (_graphMetricIndex + 1) % 2;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  _graphMetricIndex == 0 ? 'EMG Graph' : 'Angle Graph',
                                  style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.swap_horiz_rounded, color: Colors.white38, size: 10),
                              ],
                            ),
                          ),
                          Text(
                            _graphMetricIndex == 0
                                ? (_isDemoMode || _currentReading.isConnected
                                    ? '${_currentReading.emgActivationPct.round()}%'
                                    : '--%')
                                : '${_currentAngle.toStringAsFixed(0)}°',
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 9, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Compact Sensor Graph
                      SizedBox(
                        height: 26,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _MiniSensorGraphPainter(
                            data: _graphPoints,
                            lineColor: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      // Rep, Angle & Form Metrics Row
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'REP ${_currentRep.toString().padLeft(2, '0')}/${_targetReps.toString().padLeft(2, '0')}',
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.35)),
                              ),
                              child: Text(
                                'ANGLE ${_currentAngle.toStringAsFixed(0)}°',
                                style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 8.5, fontWeight: FontWeight.w900),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'FORM $formAccuracy%',
                              style: TextStyle(
                                color: formAccuracy >= 80 ? AppColors.success : AppColors.warning,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Compact Action Controls: [ PAUSE ] and [ STOP ]
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        // PAUSE / RESUME
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isPaused = !_isPaused;
                              });
                              if (_isPaused) {
                                _sensorDataSource.pause();
                              } else {
                                _sensorDataSource.resume();
                              }
                              if (_voiceEnabled) {
                                TtsService().speak(_isPaused ? 'Exercise paused' : 'Resuming exercise');
                              }
                            },
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              height: 30,
                              decoration: BoxDecoration(
                                color: _isPaused ? AppColors.success : Colors.white10,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 14, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    _isPaused ? 'RESUME' : 'PAUSE',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // STOP
                        Expanded(
                          child: InkWell(
                            onTap: _finishSession,
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.stop_rounded, size: 14, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'STOP',
                                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniSensorChip({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String unit,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 2),
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 8.5, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            '$value $unit',
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

/// Lightweight painter for the live sensor graph.
class _MiniSensorGraphPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _MiniSensorGraphPainter({
    required this.data,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paintLine = Paint()
      ..color = lineColor
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paintGrid = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // Draw baseline and midpoint reference grid
    canvas.drawLine(Offset(0, size.height * 0.5), Offset(size.width, size.height * 0.5), paintGrid);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paintGrid);

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (data.length - 1);
    const maxY = 100.0;

    double getY(double val) {
      final norm = (val / maxY).clamp(0.0, 1.0);
      return size.height - (norm * size.height);
    }

    path.moveTo(0, getY(data.first));
    fillPath.moveTo(0, size.height);
    fillPath.lineTo(0, getY(data.first));

    for (int i = 0; i < data.length - 1; i++) {
      final x1 = i * stepX;
      final y1 = getY(data[i]);
      final x2 = (i + 1) * stepX;
      final y2 = getY(data[i + 1]);

      final cx = (x1 + x2) / 2;
      path.cubicTo(cx, y1, cx, y2, x2, y2);
      fillPath.cubicTo(cx, y1, cx, y2, x2, y2);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Gradient fill under curve
    final paintFill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    // Glowing dot at the current reading
    final lastX = size.width;
    final lastY = getY(data.last);
    final dotPaint = Paint()..color = Colors.white;
    final haloPaint = Paint()..color = lineColor.withValues(alpha: 0.4);

    canvas.drawCircle(Offset(lastX, lastY), 4.0, haloPaint);
    canvas.drawCircle(Offset(lastX, lastY), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSensorGraphPainter oldDelegate) => true;
}
