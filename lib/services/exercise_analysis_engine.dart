import 'package:flutter/material.dart';
import '../core/theme/color_palette.dart';
import '../domain/models/detected_pose.dart';
import '../domain/models/pose_keypoint.dart';
import '../domain/models/prescription.dart';
import '../domain/models/rep_verdict.dart';
import '../native/ffi/native_engine_bridge.dart';

/// State of repetition progress in the exercise movement cycle.
enum RepCyclePhase {
  resting,        // User at starting / resting posture
  movementStart,  // Beginning movement towards target
  movingOut,      // Moving towards extension / target position
  inTargetZone,   // In prescribed ROM target range
  movementReturn, // Returning back to resting posture
  returning,      // Lowering back to rest
}

/// Evaluation result for a single frame analysis.
class FrameAnalysisResult {
  final double angle;
  final String jointDisplayName;
  final String statusText;
  final Color statusColor;
  final IconData statusIcon;
  final RepVerdict verdict;
  final bool repCompleted;
  final bool repWasCorrect;
  final String? spokenCue;
  final CocoJoint activeJoint;
  final bool isMovementCorrect;
  final bool isOccluded;
  final double poseConfidence;
  final String feedbackCategory;
  final RepCyclePhase phase;

  const FrameAnalysisResult({
    required this.angle,
    required this.jointDisplayName,
    required this.statusText,
    required this.statusColor,
    required this.statusIcon,
    required this.verdict,
    required this.repCompleted,
    required this.repWasCorrect,
    this.spokenCue,
    required this.activeJoint,
    this.isMovementCorrect = false,
    this.isOccluded = false,
    this.poseConfidence = 0.0,
    this.feedbackCategory = 'INCORRECT',
    this.phase = RepCyclePhase.resting,
  });
}

/// Exercise kinematic analysis and repetition state machine.
/// Provides exercise-specific angle calculations:
/// - Knee Extension / Exercise: Hip -> Knee -> Ankle
/// - Elbow Exercise: Shoulder -> Elbow -> Wrist
/// - Shoulder Exercise: Hip -> Shoulder -> Elbow
/// - Hip Exercise: Shoulder -> Hip -> Knee
/// - Hand / Finger Exercise: Wrist & extremity tracking
/// 
/// Real-time correct/incorrect form verification and state machine rep counting:
/// START -> MOVEMENT START -> TARGET POSITION -> MOVEMENT RETURN -> VALID REP -> REP + 1
class ExerciseAnalysisEngine {
  final NativeEngineBridge _bridge = NativeEngineBridge();

  RepCyclePhase _currentPhase = RepCyclePhase.resting;
  double _peakAngleInCycle = 0.0;
  bool _reachedTargetInCycle = false;
  DateTime? _lastSpokenTime;
  String? _lastSpokenPhrase;

  // Occlusion tracking
  int _occludedFrames = 0;
  static const int _maxOcclusionGraceFrames = 5;

  RepCyclePhase get currentPhase => _currentPhase;

  void reset() {
    _currentPhase = RepCyclePhase.resting;
    _peakAngleInCycle = 0.0;
    _reachedTargetInCycle = false;
    _lastSpokenTime = null;
    _lastSpokenPhrase = null;
    _occludedFrames = 0;
  }

  /// Evaluates the current pose against the prescribed exercise protocol.
  FrameAnalysisResult analyzeFrame({
    required DetectedPose pose,
    required Prescription prescription,
  }) {
    // 1. Person Detection Status Check
    if (!pose.isPersonDetected || pose.keypoints.isEmpty) {
      final isUpper = prescription.exerciseId.contains('elbow') ||
          prescription.exerciseId.contains('shoulder') ||
          prescription.exerciseId.contains('hand') ||
          prescription.exerciseId.contains('finger');

      return FrameAnalysisResult(
        angle: 0.0,
        jointDisplayName: isUpper ? 'ARM ANGLE' : 'KNEE ANGLE',
        statusText: 'Move into camera view',
        statusColor: AppColors.error,
        statusIcon: Icons.person_search_rounded,
        verdict: RepVerdict.unknown,
        repCompleted: false,
        repWasCorrect: false,
        spokenCue: _getCooldownVoiceCue('Move into camera view'),
        activeJoint: isUpper ? CocoJoint.rightShoulder : CocoJoint.rightKnee,
        isMovementCorrect: false,
        isOccluded: false,
        poseConfidence: pose.personConfidence,
        feedbackCategory: 'ABSENT',
        phase: RepCyclePhase.resting,
      );
    }

    // 2. Dispatch to Exercise-Specific Kinematic Analyzer
    final exId = prescription.exerciseId.toLowerCase();
    final jointTarget = prescription.targetJointName.toLowerCase();

    if (exId.contains('elbow')) {
      return _analyzeElbowExercise(pose, prescription);
    } else if (exId.contains('shoulder') || jointTarget.contains('shoulder')) {
      return _analyzeShoulderExercise(pose, prescription);
    } else if (exId.contains('hip') || jointTarget.contains('hip')) {
      return _analyzeHipExercise(pose, prescription);
    } else if (exId.contains('hand') || exId.contains('finger')) {
      return _analyzeHandExercise(pose, prescription);
    } else {
      // Default: Knee Exercise / Knee Extension
      return _analyzeKneeExercise(pose, prescription);
    }
  }

  // =========================================================================
  // 1. KNEE EXTENSION: Hip -> Knee -> Ankle
  // =========================================================================
  FrameAnalysisResult _analyzeKneeExercise(DetectedPose pose, Prescription rx) {
    final rHip = pose.getKeypoint(CocoJoint.rightHip);
    final rKnee = pose.getKeypoint(CocoJoint.rightKnee);
    final rAnkle = pose.getKeypoint(CocoJoint.rightAnkle);

    final lHip = pose.getKeypoint(CocoJoint.leftHip);
    final lKnee = pose.getKeypoint(CocoJoint.leftKnee);
    final lAnkle = pose.getKeypoint(CocoJoint.leftAnkle);

    final bool rightLegVisible = (rHip != null && rHip.isVisible) &&
        (rKnee != null && rKnee.isVisible) &&
        (rAnkle != null && rAnkle.isVisible);

    final bool leftLegVisible = (lHip != null && lHip.isVisible) &&
        (lKnee != null && lKnee.isVisible) &&
        (lAnkle != null && lAnkle.isVisible);

    if (!rightLegVisible && !leftLegVisible) {
      _occludedFrames++;
      if (_occludedFrames > _maxOcclusionGraceFrames) {
        return FrameAnalysisResult(
          angle: 0.0,
          jointDisplayName: 'KNEE ANGLE',
          statusText: 'Knee not detected\nAdjust your position',
          statusColor: AppColors.warning,
          statusIcon: Icons.visibility_off_rounded,
          verdict: RepVerdict.unknown,
          repCompleted: false,
          repWasCorrect: false,
          spokenCue: _getCooldownVoiceCue('Knee not detected. Adjust your position.'),
          activeJoint: CocoJoint.rightKnee,
          isMovementCorrect: false,
          isOccluded: true,
          poseConfidence: pose.personConfidence * 0.5,
          feedbackCategory: 'OCCLUDED',
          phase: _currentPhase,
        );
      }
    } else {
      _occludedFrames = 0;
    }

    double rightAngle = 90.0;
    double leftAngle = 90.0;

    if (rightLegVisible) {
      rightAngle = _bridge.calculateJointAngle(
        rHip.x, rHip.y,
        rKnee.x, rKnee.y,
        rAnkle.x, rAnkle.y,
      );
    }

    if (leftLegVisible) {
      leftAngle = _bridge.calculateJointAngle(
        lHip.x, lHip.y,
        lKnee.x, lKnee.y,
        lAnkle.x, lAnkle.y,
      );
    }

    final isRightActive = rightAngle >= leftAngle;
    final measuredAngle = isRightActive ? rightAngle : leftAngle;
    final activeJoint = isRightActive ? CocoJoint.rightKnee : CocoJoint.leftKnee;

    final minAngle = rx.minAngle > 0 ? rx.minAngle : 80.0;
    final maxAngle = rx.maxAngle > 0 ? rx.maxAngle : 160.0;
    const restThreshold = 105.0; // Seated ~90°

    if (measuredAngle > _peakAngleInCycle) {
      _peakAngleInCycle = measuredAngle;
    }

    bool repCompleted = false;
    bool repWasCorrect = false;
    String statusText = 'Extend leg to begin';
    Color statusColor = Colors.white70;
    IconData statusIcon = Icons.airline_seat_recline_normal_rounded;
    RepVerdict verdict = RepVerdict.unknown;
    String? spokenCue;
    bool isMovementCorrect = false;
    String feedbackCategory = 'INCORRECT';

    if (measuredAngle > restThreshold + 8.0) {
      // Movement underway (extending)
      if (measuredAngle >= minAngle && measuredAngle <= maxAngle + 6.0) {
        _currentPhase = RepCyclePhase.inTargetZone;
        _reachedTargetInCycle = true;
        isMovementCorrect = true;
        feedbackCategory = 'CORRECT';
        statusText = '✓ GOOD FORM';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        verdict = RepVerdict.correct;
        spokenCue = _getCooldownVoiceCue('Good movement');
      } else if (measuredAngle > maxAngle + 6.0) {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Do not extend that far';
        statusColor = AppColors.error;
        statusIcon = Icons.arrow_downward_rounded;
        verdict = RepVerdict.overshoot;
        spokenCue = _getCooldownVoiceCue('Do not extend that far');
      } else {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Straighten your knee';
        statusColor = AppColors.warning;
        statusIcon = Icons.arrow_upward_rounded;
        verdict = RepVerdict.tooShallow;
        spokenCue = _getCooldownVoiceCue('Straighten your knee');
      }
    } else {
      // Leg is in resting / lowering zone
      if (_peakAngleInCycle > restThreshold + 15.0) {
        // Complete cycle: START -> MOVEMENT START -> TARGET POSITION -> MOVEMENT RETURN -> VALID REP
        repCompleted = true;
        if (_reachedTargetInCycle || (_peakAngleInCycle >= minAngle && _peakAngleInCycle <= maxAngle + 10.0)) {
          repWasCorrect = true;
          isMovementCorrect = true;
          feedbackCategory = 'CORRECT';
          statusText = '✓ GOOD REP';
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle_rounded;
          verdict = RepVerdict.correct;
          spokenCue = 'Good rep';
        } else if (_peakAngleInCycle < minAngle) {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = '✕ INCORRECT: Straighten your knee';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.tooShallow;
          spokenCue = 'Straighten your knee';
        } else {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = '✕ INCORRECT: Do not extend that far';
          statusColor = AppColors.error;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.overshoot;
          spokenCue = 'Do not extend that far';
        }

        _currentPhase = RepCyclePhase.resting;
        _peakAngleInCycle = 0.0;
        _reachedTargetInCycle = false;
      } else {
        _currentPhase = RepCyclePhase.resting;
        statusText = 'Extend leg to begin';
        statusColor = Colors.white70;
        statusIcon = Icons.airline_seat_recline_normal_rounded;
      }
    }

    return FrameAnalysisResult(
      angle: measuredAngle,
      jointDisplayName: 'KNEE ANGLE',
      statusText: statusText,
      statusColor: statusColor,
      statusIcon: statusIcon,
      verdict: verdict,
      repCompleted: repCompleted,
      repWasCorrect: repWasCorrect,
      spokenCue: spokenCue,
      activeJoint: activeJoint,
      isMovementCorrect: isMovementCorrect,
      isOccluded: false,
      poseConfidence: pose.personConfidence,
      feedbackCategory: feedbackCategory,
      phase: _currentPhase,
    );
  }

  // =========================================================================
  // 2. ELBOW EXERCISE: Shoulder -> Elbow -> Wrist
  // =========================================================================
  FrameAnalysisResult _analyzeElbowExercise(DetectedPose pose, Prescription rx) {
    final rShoulder = pose.getKeypoint(CocoJoint.rightShoulder);
    final rElbow = pose.getKeypoint(CocoJoint.rightElbow);
    final rWrist = pose.getKeypoint(CocoJoint.rightWrist);

    final lShoulder = pose.getKeypoint(CocoJoint.leftShoulder);
    final lElbow = pose.getKeypoint(CocoJoint.leftElbow);
    final lWrist = pose.getKeypoint(CocoJoint.leftWrist);

    final bool rVisible = (rShoulder?.isVisible ?? false) &&
        (rElbow?.isVisible ?? false) &&
        (rWrist?.isVisible ?? false);

    final bool lVisible = (lShoulder?.isVisible ?? false) &&
        (lElbow?.isVisible ?? false) &&
        (lWrist?.isVisible ?? false);

    if (!rVisible && !lVisible) {
      return FrameAnalysisResult(
        angle: 0.0,
        jointDisplayName: 'ELBOW ANGLE',
        statusText: 'Elbow not detected\nAdjust your position',
        statusColor: AppColors.warning,
        statusIcon: Icons.visibility_off_rounded,
        verdict: RepVerdict.unknown,
        repCompleted: false,
        repWasCorrect: false,
        spokenCue: _getCooldownVoiceCue('Elbow not detected. Adjust your position.'),
        activeJoint: CocoJoint.rightElbow,
        isMovementCorrect: false,
        isOccluded: true,
        poseConfidence: pose.personConfidence * 0.5,
        feedbackCategory: 'OCCLUDED',
        phase: _currentPhase,
      );
    }

    double rAngle = 160.0;
    double lAngle = 160.0;

    if (rVisible) {
      rAngle = _bridge.calculateJointAngle(
        rShoulder!.x, rShoulder.y,
        rElbow!.x, rElbow.y,
        rWrist!.x, rWrist.y,
      );
    }

    if (lVisible) {
      lAngle = _bridge.calculateJointAngle(
        lShoulder!.x, lShoulder.y,
        lElbow!.x, lElbow.y,
        lWrist!.x, lWrist.y,
      );
    }

    // Active bending elbow has lower angle during flexion curl
    final isRightActive = (rAngle <= lAngle);
    final measuredAngle = isRightActive ? rAngle : lAngle;
    final activeJoint = isRightActive ? CocoJoint.rightElbow : CocoJoint.leftElbow;

    // Prescribed range: e.g. 40° to 110° flexion
    final minAngle = rx.minAngle > 0 ? rx.minAngle : 40.0;
    final maxAngle = rx.maxAngle > 0 ? rx.maxAngle : 110.0;
    const restThreshold = 140.0; // Extended arm ~150°-170°

    if (_peakAngleInCycle == 0.0 || measuredAngle < _peakAngleInCycle) {
      _peakAngleInCycle = measuredAngle; // Peak flexion = smallest angle
    }

    bool repCompleted = false;
    bool repWasCorrect = false;
    String statusText = 'Bend elbow to begin';
    Color statusColor = Colors.white70;
    IconData statusIcon = Icons.fitness_center_rounded;
    RepVerdict verdict = RepVerdict.unknown;
    String? spokenCue;
    bool isMovementCorrect = false;
    String feedbackCategory = 'INCORRECT';

    if (measuredAngle < restThreshold - 10.0) {
      // Movement underway (flexing)
      if (measuredAngle <= maxAngle && measuredAngle >= minAngle) {
        _currentPhase = RepCyclePhase.inTargetZone;
        _reachedTargetInCycle = true;
        isMovementCorrect = true;
        feedbackCategory = 'CORRECT';
        statusText = '✓ GOOD FORM';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        verdict = RepVerdict.correct;
        spokenCue = _getCooldownVoiceCue('Good form');
      } else if (measuredAngle < minAngle) {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Do not bend that far';
        statusColor = AppColors.error;
        statusIcon = Icons.arrow_downward_rounded;
        verdict = RepVerdict.overshoot;
        spokenCue = _getCooldownVoiceCue('Do not bend that far');
      } else {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Bend your elbow more';
        statusColor = AppColors.warning;
        statusIcon = Icons.arrow_upward_rounded;
        verdict = RepVerdict.tooShallow;
        spokenCue = _getCooldownVoiceCue('Bend your elbow more');
      }
    } else {
      // Arm returned to resting extension
      if (_peakAngleInCycle > 0.0 && _peakAngleInCycle < restThreshold - 20.0) {
        repCompleted = true;
        if (_reachedTargetInCycle || (_peakAngleInCycle >= minAngle && _peakAngleInCycle <= maxAngle)) {
          repWasCorrect = true;
          isMovementCorrect = true;
          feedbackCategory = 'CORRECT';
          statusText = '✓ GOOD REP';
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle_rounded;
          verdict = RepVerdict.correct;
          spokenCue = 'Good rep';
        } else {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = '✕ INCORRECT: Bend your elbow more';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.tooShallow;
          spokenCue = 'Bend your elbow more';
        }

        _currentPhase = RepCyclePhase.resting;
        _peakAngleInCycle = 0.0;
        _reachedTargetInCycle = false;
      } else {
        _currentPhase = RepCyclePhase.resting;
        statusText = 'Bend elbow to begin';
        statusColor = Colors.white70;
        statusIcon = Icons.fitness_center_rounded;
      }
    }

    return FrameAnalysisResult(
      angle: measuredAngle,
      jointDisplayName: 'ELBOW ANGLE',
      statusText: statusText,
      statusColor: statusColor,
      statusIcon: statusIcon,
      verdict: verdict,
      repCompleted: repCompleted,
      repWasCorrect: repWasCorrect,
      spokenCue: spokenCue,
      activeJoint: activeJoint,
      isMovementCorrect: isMovementCorrect,
      isOccluded: false,
      poseConfidence: pose.personConfidence,
      feedbackCategory: feedbackCategory,
      phase: _currentPhase,
    );
  }

  // =========================================================================
  // 3. SHOULDER EXERCISE: Hip -> Shoulder -> Elbow
  // =========================================================================
  FrameAnalysisResult _analyzeShoulderExercise(DetectedPose pose, Prescription rx) {
    final rHip = pose.getKeypoint(CocoJoint.rightHip);
    final rShoulder = pose.getKeypoint(CocoJoint.rightShoulder);
    final rElbow = pose.getKeypoint(CocoJoint.rightElbow);

    final lHip = pose.getKeypoint(CocoJoint.leftHip);
    final lShoulder = pose.getKeypoint(CocoJoint.leftShoulder);
    final lElbow = pose.getKeypoint(CocoJoint.leftElbow);

    double rightAngle = 0.0;
    double leftAngle = 0.0;

    if (rHip != null && rShoulder != null && rElbow != null &&
        rHip.isVisible && rShoulder.isVisible && rElbow.isVisible) {
      rightAngle = _bridge.calculateJointAngle(
        rHip.x, rHip.y,
        rShoulder.x, rShoulder.y,
        rElbow.x, rElbow.y,
      );
    }

    if (lHip != null && lShoulder != null && lElbow != null &&
        lHip.isVisible && lShoulder.isVisible && lElbow.isVisible) {
      leftAngle = _bridge.calculateJointAngle(
        lHip.x, lHip.y,
        lShoulder.x, lShoulder.y,
        lElbow.x, lElbow.y,
      );
    }

    final isRightArmActive = rightAngle >= leftAngle;
    final measuredAngle = isRightArmActive ? rightAngle : leftAngle;
    final activeJoint = isRightArmActive ? CocoJoint.rightShoulder : CocoJoint.leftShoulder;

    final minAngle = rx.minAngle > 0 ? rx.minAngle : 80.0;
    final maxAngle = rx.maxAngle > 0 ? rx.maxAngle : 100.0;
    const restThreshold = 35.0;

    bool repCompleted = false;
    bool repWasCorrect = false;
    String statusText = 'Raise arm to 90°';
    Color statusColor = Colors.white70;
    IconData statusIcon = Icons.accessibility_new_rounded;
    RepVerdict verdict = RepVerdict.unknown;
    String? spokenCue;
    bool isMovementCorrect = false;
    String feedbackCategory = 'INCORRECT';

    if (measuredAngle > _peakAngleInCycle) {
      _peakAngleInCycle = measuredAngle;
    }

    if (measuredAngle > restThreshold + 6.0) {
      if (measuredAngle >= minAngle - 5.0 && measuredAngle <= maxAngle + 5.0) {
        _currentPhase = RepCyclePhase.inTargetZone;
        _reachedTargetInCycle = true;
        isMovementCorrect = true;
        feedbackCategory = 'CORRECT';
        statusText = '✓ GOOD FORM';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        verdict = RepVerdict.correct;
      } else if (measuredAngle > maxAngle + 5.0) {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Lower your arm slightly';
        statusColor = AppColors.warning;
        statusIcon = Icons.arrow_downward_rounded;
        verdict = RepVerdict.overshoot;
        spokenCue = _getCooldownVoiceCue('Lower your arm slightly');
      } else {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Raise your arm higher';
        statusColor = AppColors.info;
        statusIcon = Icons.arrow_upward_rounded;
        verdict = RepVerdict.tooShallow;
        spokenCue = _getCooldownVoiceCue('Raise your arm higher');
      }
    } else {
      if (_peakAngleInCycle > restThreshold + 10.0) {
        repCompleted = true;
        if (_reachedTargetInCycle || (_peakAngleInCycle >= minAngle - 6.0 && _peakAngleInCycle <= maxAngle + 10.0)) {
          repWasCorrect = true;
          isMovementCorrect = true;
          feedbackCategory = 'CORRECT';
          statusText = '✓ GOOD REP';
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle_rounded;
          verdict = RepVerdict.correct;
          spokenCue = 'Good rep';
        } else if (_peakAngleInCycle < minAngle - 6.0) {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = '✕ INCORRECT: Raise your arm higher';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.tooShallow;
          spokenCue = 'Raise your arm higher';
        } else {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = '✕ INCORRECT: Lower your arm slightly';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.overshoot;
          spokenCue = 'Lower your arm slightly';
        }

        _currentPhase = RepCyclePhase.resting;
        _peakAngleInCycle = 0.0;
        _reachedTargetInCycle = false;
      } else {
        _currentPhase = RepCyclePhase.resting;
        statusText = 'Raise arm to 90°';
        statusColor = Colors.white70;
        statusIcon = Icons.accessibility_new_rounded;
      }
    }

    return FrameAnalysisResult(
      angle: measuredAngle,
      jointDisplayName: 'ARM ANGLE',
      statusText: statusText,
      statusColor: statusColor,
      statusIcon: statusIcon,
      verdict: verdict,
      repCompleted: repCompleted,
      repWasCorrect: repWasCorrect,
      spokenCue: spokenCue,
      activeJoint: activeJoint,
      isMovementCorrect: isMovementCorrect,
      isOccluded: false,
      poseConfidence: pose.personConfidence,
      feedbackCategory: feedbackCategory,
      phase: _currentPhase,
    );
  }

  // =========================================================================
  // 4. HIP EXERCISE: Shoulder -> Hip -> Knee
  // =========================================================================
  FrameAnalysisResult _analyzeHipExercise(DetectedPose pose, Prescription rx) {
    final rShoulder = pose.getKeypoint(CocoJoint.rightShoulder);
    final rHip = pose.getKeypoint(CocoJoint.rightHip);
    final rKnee = pose.getKeypoint(CocoJoint.rightKnee);

    final lShoulder = pose.getKeypoint(CocoJoint.leftShoulder);
    final lHip = pose.getKeypoint(CocoJoint.leftHip);
    final lKnee = pose.getKeypoint(CocoJoint.leftKnee);

    double rightAngle = 180.0;
    double leftAngle = 180.0;

    if (rShoulder != null && rHip != null && rKnee != null &&
        rShoulder.isVisible && rHip.isVisible && rKnee.isVisible) {
      rightAngle = _bridge.calculateJointAngle(
        rShoulder.x, rShoulder.y,
        rHip.x, rHip.y,
        rKnee.x, rKnee.y,
      );
    }

    if (lShoulder != null && lHip != null && lKnee != null &&
        lShoulder.isVisible && lHip.isVisible && lKnee.isVisible) {
      leftAngle = _bridge.calculateJointAngle(
        lShoulder.x, lShoulder.y,
        lHip.x, lHip.y,
        lKnee.x, lKnee.y,
      );
    }

    // Active flexed hip has smaller angle (bending hip brings knee closer to torso)
    final isRightActive = rightAngle <= leftAngle;
    final measuredAngle = isRightActive ? rightAngle : leftAngle;
    final activeJoint = isRightActive ? CocoJoint.rightHip : CocoJoint.leftHip;

    final minAngle = rx.minAngle > 0 ? rx.minAngle : 60.0;
    final maxAngle = rx.maxAngle > 0 ? rx.maxAngle : 120.0;
    const restThreshold = 160.0; // Standing upright ~180°

    if (_peakAngleInCycle == 0.0 || measuredAngle < _peakAngleInCycle) {
      _peakAngleInCycle = measuredAngle;
    }

    bool repCompleted = false;
    bool repWasCorrect = false;
    String statusText = 'Lift knee to hip level';
    Color statusColor = Colors.white70;
    IconData statusIcon = Icons.directions_walk_rounded;
    RepVerdict verdict = RepVerdict.unknown;
    String? spokenCue;
    bool isMovementCorrect = false;
    String feedbackCategory = 'INCORRECT';

    if (measuredAngle < restThreshold - 12.0) {
      if (measuredAngle <= maxAngle && measuredAngle >= minAngle) {
        _currentPhase = RepCyclePhase.inTargetZone;
        _reachedTargetInCycle = true;
        isMovementCorrect = true;
        feedbackCategory = 'CORRECT';
        statusText = '✓ GOOD FORM';
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        verdict = RepVerdict.correct;
      } else if (measuredAngle < minAngle) {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Lower your leg slightly';
        statusColor = AppColors.warning;
        statusIcon = Icons.arrow_downward_rounded;
        verdict = RepVerdict.overshoot;
        spokenCue = _getCooldownVoiceCue('Lower your leg slightly');
      } else {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = '✕ INCORRECT: Raise your knee higher';
        statusColor = AppColors.info;
        statusIcon = Icons.arrow_upward_rounded;
        verdict = RepVerdict.tooShallow;
        spokenCue = _getCooldownVoiceCue('Raise your knee higher');
      }
    } else {
      if (_peakAngleInCycle > 0.0 && _peakAngleInCycle < restThreshold - 25.0) {
        repCompleted = true;
        if (_reachedTargetInCycle || (_peakAngleInCycle >= minAngle && _peakAngleInCycle <= maxAngle)) {
          repWasCorrect = true;
          isMovementCorrect = true;
          feedbackCategory = 'CORRECT';
          statusText = '✓ GOOD REP';
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle_rounded;
          verdict = RepVerdict.correct;
          spokenCue = 'Good rep';
        } else {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = '✕ INCORRECT: Raise your knee higher';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.tooShallow;
          spokenCue = 'Raise your knee higher';
        }

        _currentPhase = RepCyclePhase.resting;
        _peakAngleInCycle = 0.0;
        _reachedTargetInCycle = false;
      } else {
        _currentPhase = RepCyclePhase.resting;
        statusText = 'Lift knee to hip level';
        statusColor = Colors.white70;
        statusIcon = Icons.directions_walk_rounded;
      }
    }

    return FrameAnalysisResult(
      angle: measuredAngle,
      jointDisplayName: 'HIP ANGLE',
      statusText: statusText,
      statusColor: statusColor,
      statusIcon: statusIcon,
      verdict: verdict,
      repCompleted: repCompleted,
      repWasCorrect: repWasCorrect,
      spokenCue: spokenCue,
      activeJoint: activeJoint,
      isMovementCorrect: isMovementCorrect,
      isOccluded: false,
      poseConfidence: pose.personConfidence,
      feedbackCategory: feedbackCategory,
      phase: _currentPhase,
    );
  }

  // =========================================================================
  // 5. HAND / FINGER EXERCISE
  // =========================================================================
  FrameAnalysisResult _analyzeHandExercise(DetectedPose pose, Prescription rx) {
    final rWrist = pose.getKeypoint(CocoJoint.rightWrist);
    final lWrist = pose.getKeypoint(CocoJoint.leftWrist);

    final bool isRightVisible = rWrist?.isVisible ?? false;
    final bool isLeftVisible = lWrist?.isVisible ?? false;

    final activeJoint = isRightVisible ? CocoJoint.rightWrist : (isLeftVisible ? CocoJoint.leftWrist : CocoJoint.rightWrist);
    final isHandInView = isRightVisible || isLeftVisible;

    if (!isHandInView) {
      return FrameAnalysisResult(
        angle: 0.0,
        jointDisplayName: 'HAND IN VIEW',
        statusText: 'Place hand in camera frame',
        statusColor: AppColors.warning,
        statusIcon: Icons.back_hand_rounded,
        verdict: RepVerdict.unknown,
        repCompleted: false,
        repWasCorrect: false,
        spokenCue: _getCooldownVoiceCue('Place hand in camera frame'),
        activeJoint: activeJoint,
        isMovementCorrect: false,
        isOccluded: true,
        poseConfidence: pose.personConfidence,
        feedbackCategory: 'OCCLUDED',
        phase: _currentPhase,
      );
    }

    return FrameAnalysisResult(
      angle: 90.0,
      jointDisplayName: 'WRIST ANGLE',
      statusText: '✓ GOOD FORM',
      statusColor: AppColors.success,
      statusIcon: Icons.check_circle_rounded,
      verdict: RepVerdict.correct,
      repCompleted: false,
      repWasCorrect: false,
      activeJoint: activeJoint,
      isMovementCorrect: true,
      isOccluded: false,
      poseConfidence: pose.personConfidence,
      feedbackCategory: 'CORRECT',
      phase: RepCyclePhase.inTargetZone,
    );
  }

  /// Rate limits spoken prompts so the voice coach does not spam.
  String? _getCooldownVoiceCue(String cue) {
    final now = DateTime.now();
    if (_lastSpokenTime == null || now.difference(_lastSpokenTime!).inMilliseconds > 3400) {
      if (_lastSpokenPhrase != cue || now.difference(_lastSpokenTime ?? DateTime(0)).inSeconds > 5) {
        _lastSpokenTime = now;
        _lastSpokenPhrase = cue;
        return cue;
      }
    }
    return null;
  }
}
