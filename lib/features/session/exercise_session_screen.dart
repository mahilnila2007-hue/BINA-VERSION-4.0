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
import '../../domain/models/session_record.dart';
import '../../domain/services/haptic_service.dart';
import '../../domain/services/tts_service.dart';
import '../../services/camera_service.dart';
import '../../services/exercise_analysis_engine.dart';
import '../../services/yolo_pose_service.dart';
import '../../widgets/pose_skeleton_painter.dart';
import '../../widgets/responsive_screen_frame.dart';
import '../auth/auth_provider.dart';

/// Professional AI Rehabilitation Live Exercise Monitoring Screen.
/// 
/// Integrates the real YOLO Pose detection module into the continuous camera feed:
/// - Real Android camera preview
/// - YOLO Pose 17 COCO keypoints skeleton overlay
/// - Exercise-specific joint angle calculations (Knee, Elbow, Shoulder, Hip, Hand)
/// - Real-time form feedback (✓ GOOD REP / ✕ INCORRECT)
/// - Multi-phase state machine repetition counting
/// - Person detection status & Vision AI lifecycle tracking
/// - Developer / Debug telemetry panel
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
  bool _demoModeEnabled = false; // Real hardware disconnected by default
  bool _showDebugPanel = false;  // Developer / Debug Telemetry Toggle

  // Telemetry Time-Series for Sensor Graph
  final List<double> _graphPoints = List.generate(24, (_) => 15.0);
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

    _initCameraAndAI();
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
          _updateGraphData();
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
          emgActivation: _demoModeEnabled ? 74.0 : 0.0,
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

  void _updateGraphData() {
    double nextValue;
    if (_graphMetricIndex == 0) {
      // EMG Muscle Activation
      if (_demoModeEnabled) {
        final isContracting = _currentAngle > (_minAllowedAngle - 10.0);
        nextValue = isContracting
            ? (65.0 + math.Random().nextDouble() * 25.0)
            : (10.0 + math.Random().nextDouble() * 12.0);
      } else {
        nextValue = 0.0;
      }
    } else {
      // Joint Angle (0-180 mapped to 0-100%)
      nextValue = (_currentAngle / 180.0 * 100.0).clamp(0.0, 100.0);
    }

    _graphPoints.removeAt(0);
    _graphPoints.add(nextValue);
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
      maxHR: _demoModeEnabled ? 78 : 0,
      minSpO2: _demoModeEnabled ? 98 : 0,
      temperature: _demoModeEnabled ? 27.2 : 0.0,
      humidity: _demoModeEnabled ? 60.0 : 0.0,
      averageEmg: _demoModeEnabled ? 44.0 : 0.0,
      peakEmg: _demoModeEnabled ? 88.0 : 0.0,
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
                color: AppColors.primary.withOpacity(0.18),
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
                      color: AppColors.primary.withOpacity(0.92),
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

              // 2. TOP 50–55%: REAL CAMERA + YOLO SKELETON (HERO VIEW)
              Expanded(
                flex: 11,
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

                        // C. Centered Small Prompt if No Person Detected or Joint Occluded
                        if (!_currentPose.isPersonDetected)
                          _buildNoPersonOverlay()
                        else if (_isOccluded)
                          _buildOcclusionOverlay(),

                        // D. Top-Left Translucent Info Pill: Joint Angle & Target ROM
                        Positioned(
                          top: 10,
                          left: 12,
                          child: _buildAngleRomIndicator(
                            jointLabel: rx.targetJointName,
                          ),
                        ),

                        // E. Top-Right: Person Detection Status & Vision AI Status Badges
                        Positioned(
                          top: 10,
                          right: 12,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _buildPersonDetectionStatusChip(),
                              const SizedBox(height: 4),
                              _buildVisionAiStatusBadge(),
                            ],
                          ),
                        ),

                        // F. Bottom-Center: Translucent Live Form Status Pill
                        Positioned(
                          bottom: 10,
                          left: 16,
                          right: 16,
                          child: _buildFloatingStatusPill(),
                        ),

                        // G. Developer / Debug Telemetry Panel Overlay
                        if (_showDebugPanel)
                          Positioned(
                            bottom: 56,
                            right: 12,
                            child: _buildDebugTelemetryPanel(rx),
                          ),
                      ],
                    );
                  },
                ),
              ),

              // 3. BOTTOM 45–50%: HORIZONTAL ROW SPLIT (SIDE-BY-SIDE)
              Expanded(
                flex: 10,
                child: Container(
                  color: AppColors.backgroundDark,
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // LEFT PANEL = HOW TO DO
                      Expanded(
                        flex: 1,
                        child: _buildHowToPanel(rx),
                      ),
                      const SizedBox(width: 8),

                      // RIGHT PANEL = LIVE DASHBOARD
                      Expanded(
                        flex: 1,
                        child: _buildLiveDashboardPanel(rx),
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
                fontSize: 15,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Current Set Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'SET $_currentSet/$_totalSets',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
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
  // 2. LIVE CAMERA FEED & COMPACT OVERLAYS (TOP 50%)
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
        color: Colors.black.withOpacity(0.78),
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
                  ? const Color(0xFF10B981).withOpacity(0.2)
                  : AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: inRange
                    ? const Color(0xFF10B981).withOpacity(0.5)
                    : AppColors.primaryLight.withOpacity(0.4),
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

  /// Section 4: Person Detection Status Chip
  Widget _buildPersonDetectionStatusChip() {
    final isDetected = _currentPose.isPersonDetected;
    final conf = _currentPose.personConfidence;
    final isLowConf = isDetected && conf < 0.45;

    Color badgeColor;
    String titleText;
    String subText;

    if (!isDetected) {
      badgeColor = AppColors.error;
      titleText = 'NO PERSON DETECTED';
      subText = 'Move into camera view';
    } else if (isLowConf) {
      badgeColor = AppColors.warning;
      titleText = 'LOW CONFIDENCE';
      subText = 'Improve lighting or camera position';
    } else {
      badgeColor = AppColors.success;
      titleText = 'PERSON DETECTED';
      subText = 'Confidence: ${conf.toStringAsFixed(2)}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.80),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.8), width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                titleText,
                style: TextStyle(
                  color: badgeColor,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          Text(
            subText,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
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
        color: Colors.black.withOpacity(0.80),
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
        color: Colors.black.withOpacity(0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
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

  /// Floating Status Pill: Translucent, High-Contrast Coaching Prompt (✓ GOOD REP / ✕ INCORRECT)
  Widget _buildFloatingStatusPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _feedbackColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: _feedbackColor.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_feedbackIcon, size: 20, color: Colors.white),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _currentFeedback,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13.5,
                letterSpacing: 0.3,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Centered Subtle "Move into camera view" Prompt
  Widget _buildNoPersonOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 36),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white24, width: 1.0),
        ),
        child: const Text(
          'Position yourself in front of the camera',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Centered "Joint Not Detected" Prompt
  Widget _buildOcclusionOverlay() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warning, width: 1.4),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.visibility_off_rounded, color: AppColors.warning, size: 30),
            SizedBox(height: 6),
            Text(
              'TARGET JOINT NOT DETECTED',
              style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 2),
            Text(
              'Adjust your position to keep limb in camera view',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. LEFT PANEL = HOW TO DO (Bottom Left 50%)
  // =========================================================================
  Widget _buildHowToPanel(Prescription rx) {
    final instructionsList = rx.instructions
        .split('\n')
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(10),
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
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.1,
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
                              style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Step-by-step instructions
                      ...instructionsList.map(
                        (step) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Text(
                            step,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Watch Video Button
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: InkWell(
                      onTap: () => _showTutorialDialog(rx),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primaryLight.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.play_circle_fill_rounded, color: AppColors.primaryLight, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Watch Video',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
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
  // 4. RIGHT PANEL = LIVE DASHBOARD (Bottom Right 50%)
  // =========================================================================
  Widget _buildLiveDashboardPanel(Prescription rx) {
    final formAccuracy = _currentRep > 0
        ? ((_correctReps / _currentRep) * 100).toInt()
        : 100;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      padding: const EdgeInsets.all(10),
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
                      // Header Row: LIVE DASHBOARD + Demo Trigger
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'LIVE DASHBOARD',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _demoModeEnabled = !_demoModeEnabled;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: _demoModeEnabled ? AppColors.success.withOpacity(0.2) : Colors.white10,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: _demoModeEnabled ? AppColors.success : Colors.white24,
                                ),
                              ),
                              child: Text(
                                _demoModeEnabled ? 'ESP32 ON' : 'NO SENSOR',
                                style: TextStyle(
                                  color: _demoModeEnabled ? AppColors.success : Colors.white54,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Sensor Biosignal Rows
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildMiniSensorChip(
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFFEF4444),
                            label: 'HR',
                            value: _demoModeEnabled ? '78' : '--',
                            unit: 'BPM',
                          ),
                          _buildMiniSensorChip(
                            icon: Icons.water_drop_rounded,
                            color: const Color(0xFF3B82F6),
                            label: 'SpO₂',
                            value: _demoModeEnabled ? '98' : '--',
                            unit: '%',
                          ),
                          _buildMiniSensorChip(
                            icon: Icons.bolt_rounded,
                            color: const Color(0xFFF59E0B),
                            label: 'EMG',
                            value: _demoModeEnabled ? '44' : '--',
                            unit: '%',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Divider Line
                      Container(height: 1, color: Colors.white10),
                      const SizedBox(height: 6),

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
                                  style: const TextStyle(color: Colors.white54, fontSize: 9.5, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 3),
                                const Icon(Icons.swap_horiz_rounded, color: Colors.white38, size: 10),
                              ],
                            ),
                          ),
                          Text(
                            _graphMetricIndex == 0 ? '${_graphPoints.last.toStringAsFixed(0)}%' : '${_currentAngle.toStringAsFixed(0)}°',
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 9.5, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Compact Sensor Graph
                      SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _MiniSensorGraphPainter(
                            data: _graphPoints,
                            lineColor: AppColors.primaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Rep & Angle Metrics
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'REP ${_currentRep.toString().padLeft(2, '0')}/${_targetReps.toString().padLeft(2, '0')}',
                            style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E5FF).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.35)),
                            ),
                            child: Text(
                              'ANGLE ${_currentAngle.toStringAsFixed(0)}°',
                              style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 9.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                          Text(
                            'FORM $formAccuracy%',
                            style: TextStyle(
                              color: formAccuracy >= 80 ? AppColors.success : AppColors.warning,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Compact Action Controls: [ PAUSE ] and [ STOP ]
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        // PAUSE / RESUME
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isPaused = !_isPaused;
                              });
                              if (_voiceEnabled) {
                                TtsService().speak(_isPaused ? 'Exercise paused' : 'Resuming exercise');
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: _isPaused ? AppColors.success : Colors.white10,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white24, width: 0.8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(_isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 15, color: Colors.white),
                                  const SizedBox(width: 3),
                                  Text(
                                    _isPaused ? 'RESUME' : 'PAUSE',
                                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.stop_rounded, size: 15, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'STOP',
                                    style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800),
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
          lineColor.withOpacity(0.35),
          lineColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, paintFill);
    canvas.drawPath(path, paintLine);

    // Glowing dot at the current reading
    final lastX = size.width;
    final lastY = getY(data.last);
    final dotPaint = Paint()..color = Colors.white;
    final haloPaint = Paint()..color = lineColor.withOpacity(0.4);

    canvas.drawCircle(Offset(lastX, lastY), 4.0, haloPaint);
    canvas.drawCircle(Offset(lastX, lastY), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniSensorGraphPainter oldDelegate) => true;
}
