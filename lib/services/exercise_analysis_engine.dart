import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/color_palette.dart';
import '../domain/models/detected_pose.dart';
import '../domain/models/pose_keypoint.dart';
import '../domain/models/prescription.dart';
import '../domain/models/rep_verdict.dart';
import '../native/ffi/native_engine_bridge.dart';

/// State of repetition progress in the exercise movement cycle.
enum RepCyclePhase {
  resting, // Seated / arm down at rest
  movingOut, // Moving towards extension
  bending, // Beginning movement
  inTargetZone, // In prescribed ROM target range
  extending, // Extending
  returning, // Lowering back to rest
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
  });
}

/// Exercise kinematic analysis and repetition state machine.
/// Provides exercise-specific angle calculations (Knee Extension HIP -> KNEE -> ANKLE & Shoulder Abduction),
/// deterministic form verification against prescribed ROM, occlusion handling, and concise coaching feedback.
class ExerciseAnalysisEngine {
  final NativeEngineBridge _bridge = NativeEngineBridge();

  RepCyclePhase _currentPhase = RepCyclePhase.resting;
  double _peakAngleInCycle = 0.0;
  DateTime? _lastSpokenTime;
  String? _lastSpokenPhrase;

  // Occlusion tracking
  int _occludedFrames = 0;
  static const int _maxOcclusionGraceFrames = 5;
  double _lastKnownValidAngle = 0.0;

  RepCyclePhase get currentPhase => _currentPhase;

  void reset() {
    _currentPhase = RepCyclePhase.resting;
    _peakAngleInCycle = 0.0;
    _lastSpokenTime = null;
    _lastSpokenPhrase = null;
    _occludedFrames = 0;
    _lastKnownValidAngle = 0.0;
  }

  /// Evaluates the current pose against the prescribed exercise protocol.
  FrameAnalysisResult analyzeFrame({
    required DetectedPose pose,
    required Prescription prescription,
  }) {
    final isShoulder = prescription.exerciseId == 'shoulder_abduction' ||
        prescription.targetJointName.toLowerCase().contains('shoulder');

    // 1. Low Confidence or No Person Detected (Section 8)
    if (!pose.isPersonDetected || pose.keypoints.isEmpty || pose.personConfidence < 0.28) {
      return FrameAnalysisResult(
        angle: 0.0,
        jointDisplayName: isShoulder ? 'ARM ANGLE' : 'KNEE ANGLE',
        statusText: 'Move into camera view',
        statusColor: AppColors.error,
        statusIcon: Icons.person_search_rounded,
        verdict: RepVerdict.unknown,
        repCompleted: false,
        repWasCorrect: false,
        spokenCue: _getCooldownVoiceCue('Move into camera view'),
        activeJoint: isShoulder ? CocoJoint.rightShoulder : CocoJoint.rightKnee,
        isMovementCorrect: false,
        isOccluded: false,
        poseConfidence: pose.personConfidence,
        feedbackCategory: 'ABSENT',
      );
    }

    if (isShoulder) {
      return _analyzeShoulderAbduction(pose, prescription);
    } else {
      return _analyzeKneeExtension(pose, prescription);
    }
  }

  /// Knee Extension Analysis (Sections 4, 5, 6, 7, 8, 11)
  /// Measures knee angle between Vector 1 (HIP - KNEE) and Vector 2 (ANKLE - KNEE).
  FrameAnalysisResult _analyzeKneeExtension(
    DetectedPose pose,
    Prescription rx,
  ) {
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

    // 11. OCCLUSION HANDLING: If knee temporarily becomes hidden
    if (!rightLegVisible && !leftLegVisible) {
      _occludedFrames++;
      if (_occludedFrames > _maxOcclusionGraceFrames) {
        // Tracking lost: do not generate a false angle
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
        );
      }
    } else {
      _occludedFrames = 0; // Resume tracking automatically when visible
    }

    // 4. KNEE ANGLE CALCULATION: Vector 1 (HIP - KNEE) and Vector 2 (ANKLE - KNEE)
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

    // Select the active extending leg
    final isRightLegActive = rightAngle >= leftAngle;
    final measuredAngle = isRightLegActive ? rightAngle : leftAngle;
    final activeJoint = isRightLegActive ? CocoJoint.rightKnee : CocoJoint.leftKnee;

    _lastKnownValidAngle = measuredAngle;

    // Prescribed range: e.g. 80° - 160°
    final minAngle = rx.minAngle; // 80°
    final maxAngle = rx.maxAngle; // 160°
    const restThreshold = 105.0; // Seated ~90°

    bool repCompleted = false;
    bool repWasCorrect = false;
    String statusText = 'Extend leg to begin';
    Color statusColor = Colors.white70;
    IconData statusIcon = Icons.airline_seat_recline_normal_rounded;
    RepVerdict verdict = RepVerdict.unknown;
    String? spokenCue;
    bool isMovementCorrect = false;
    String feedbackCategory = 'INCORRECT';

    if (measuredAngle > _peakAngleInCycle) {
      _peakAngleInCycle = measuredAngle;
    }

    // 5 & 6. RANGE CHECK & SHORT LIVE CORRECTIVE FEEDBACK
    // If 80° <= Knee Angle <= 160° -> CORRECT with green indicator
    // If outside range -> INCORRECT with orange/red indicator
    if (measuredAngle > restThreshold + 8.0) {
      // Movement underway (extending)
      if (measuredAngle >= minAngle && measuredAngle <= maxAngle + 6.0) {
        _currentPhase = RepCyclePhase.inTargetZone;
        isMovementCorrect = true;
        feedbackCategory = 'CORRECT';
        statusText = 'Good movement';
        statusColor = AppColors.success; // Green
        statusIcon = Icons.check_circle_rounded;
        verdict = RepVerdict.correct;
        spokenCue = _getCooldownVoiceCue('Good movement');
      } else if (measuredAngle > maxAngle + 6.0) {
        _currentPhase = RepCyclePhase.extending;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = 'Do not extend that far';
        statusColor = AppColors.error; // Red
        statusIcon = Icons.arrow_downward_rounded;
        verdict = RepVerdict.overshoot;
        spokenCue = _getCooldownVoiceCue('Do not extend that far');
      } else {
        _currentPhase = RepCyclePhase.extending;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = 'Extend a little more';
        statusColor = AppColors.warning; // Orange
        statusIcon = Icons.arrow_upward_rounded;
        verdict = RepVerdict.tooShallow;
        spokenCue = _getCooldownVoiceCue('Extend a little more');
      }
    } else {
      // Leg is in resting / lowering zone
      if (_peakAngleInCycle > restThreshold + 15.0) {
        // Complete cycle: START -> KNEE BENDING -> TARGET RANGE -> KNEE EXTENSION -> RETURN
        repCompleted = true;
        if (_peakAngleInCycle >= minAngle && _peakAngleInCycle <= maxAngle + 10.0) {
          repWasCorrect = true;
          isMovementCorrect = true;
          feedbackCategory = 'CORRECT';
          statusText = '1 REP COMPLETED';
          statusColor = AppColors.success;
          statusIcon = Icons.check_circle_rounded;
          verdict = RepVerdict.correct;
          spokenCue = 'Good rep';
        } else if (_peakAngleInCycle < minAngle) {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = 'Extend a little more';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.tooShallow;
          spokenCue = 'Extend a little more';
        } else {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = 'Do not extend that far';
          statusColor = AppColors.error;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.overshoot;
          spokenCue = 'Do not extend that far';
        }

        _currentPhase = RepCyclePhase.resting;
        _peakAngleInCycle = 0.0;
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
    );
  }

  /// Shoulder Abduction Analysis
  FrameAnalysisResult _analyzeShoulderAbduction(
    DetectedPose pose,
    Prescription rx,
  ) {
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

    final minAngle = rx.minAngle;
    final maxAngle = rx.maxAngle;
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
        statusText = 'Lower your arm slightly';
        statusColor = AppColors.warning;
        statusIcon = Icons.arrow_downward_rounded;
        spokenCue = _getCooldownVoiceCue('Lower your arm slightly');
      } else {
        _currentPhase = RepCyclePhase.movingOut;
        isMovementCorrect = false;
        feedbackCategory = 'INCORRECT';
        statusText = 'Raise your arm higher';
        statusColor = AppColors.info;
        statusIcon = Icons.arrow_upward_rounded;
        spokenCue = _getCooldownVoiceCue('Raise your arm higher');
      }
    } else {
      if (_peakAngleInCycle > restThreshold + 10.0) {
        repCompleted = true;
        if (_peakAngleInCycle >= minAngle - 6.0 && _peakAngleInCycle <= maxAngle + 10.0) {
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
          statusText = 'Raise your arm higher';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.tooShallow;
          spokenCue = 'Raise your arm higher';
        } else {
          repWasCorrect = false;
          isMovementCorrect = false;
          feedbackCategory = 'INCORRECT';
          statusText = 'Lower your arm slightly';
          statusColor = AppColors.warning;
          statusIcon = Icons.warning_amber_rounded;
          verdict = RepVerdict.overshoot;
          spokenCue = 'Lower your arm slightly';
        }

        _currentPhase = RepCyclePhase.resting;
        _peakAngleInCycle = 0.0;
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
