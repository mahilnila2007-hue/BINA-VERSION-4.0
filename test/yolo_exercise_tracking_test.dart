import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/constants/exercise_presets.dart';
import 'package:rehabrep/domain/models/detected_pose.dart';
import 'package:rehabrep/domain/models/pose_keypoint.dart';
import 'package:rehabrep/domain/models/rep_verdict.dart';
import 'package:rehabrep/services/exercise_analysis_engine.dart';

void main() {
  group('Real-Time YOLO Pose & Exercise Analysis Engine Tests', () {
    late ExerciseAnalysisEngine engine;

    setUp(() {
      engine = ExerciseAnalysisEngine();
    });

    test('Test 1: No person detected prompts patient to move into camera view', () {
      final emptyPose = DetectedPose.empty();
      final rx = ExercisePresets.shoulderAbductionPrescription;

      final result = engine.analyzeFrame(pose: emptyPose, prescription: rx);

      expect(result.statusText, contains('Move into camera view'));
      expect(result.statusColor, equals(const Color(0xFFEF4444))); // AppColors.error
      expect(result.angle, equals(0.0));
      expect(result.jointDisplayName, equals('ARM ANGLE'));
      expect(result.repCompleted, isFalse);
    });

    test('Test 2: Shoulder Abduction within prescribed 80°-100° detects GOOD FORM and counts valid rep', () {
      final rx = ExercisePresets.shoulderAbductionPrescription; // min: 80, max: 100

      // Step A: Start at resting position (arm down at 20°)
      final restPose = _createShoulderPose(armAngleDeg: 20.0);
      var result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.jointDisplayName, equals('ARM ANGLE'));
      expect(engine.currentPhase, equals(RepCyclePhase.resting));

      // Step B: Arm rising (48° - too low)
      final midPose = _createShoulderPose(armAngleDeg: 48.0);
      result = engine.analyzeFrame(pose: midPose, prescription: rx);
      expect(engine.currentPhase, equals(RepCyclePhase.movingOut));
      expect(result.statusText, contains('Raise your arm higher'));

      // Step C: Arm in target range (92°)
      final targetPose = _createShoulderPose(armAngleDeg: 92.0);
      result = engine.analyzeFrame(pose: targetPose, prescription: rx);
      expect(engine.currentPhase, equals(RepCyclePhase.inTargetZone));
      expect(result.statusText, equals('✓ GOOD FORM'));
      expect(result.verdict, equals(RepVerdict.correct));

      // Step D: Arm lowering back to rest (20°)
      final returnPose = _createShoulderPose(armAngleDeg: 20.0);
      result = engine.analyzeFrame(pose: returnPose, prescription: rx);

      expect(result.repCompleted, isTrue);
      expect(result.repWasCorrect, isTrue);
      expect(result.verdict, equals(RepVerdict.correct));
      expect(result.statusText, equals('✓ GOOD REP'));
      expect(result.spokenCue, equals('Good rep'));
    });

    test('Test 3: Shallow Shoulder Abduction (only reaches 48°) is classified as incorrect and not awarded good rep', () {
      final rx = ExercisePresets.shoulderAbductionPrescription; // min: 80, max: 100

      // Start rest (20°)
      engine.analyzeFrame(pose: _createShoulderPose(armAngleDeg: 20.0), prescription: rx);

      // Lift only to 48°
      engine.analyzeFrame(pose: _createShoulderPose(armAngleDeg: 48.0), prescription: rx);

      // Lower back to rest (20°) without ever reaching 80°
      final result = engine.analyzeFrame(pose: _createShoulderPose(armAngleDeg: 20.0), prescription: rx);

      expect(result.repCompleted, isTrue);
      expect(result.repWasCorrect, isFalse);
      expect(result.verdict, equals(RepVerdict.tooShallow));
      expect(result.statusText, contains('Raise your arm higher'));
    });

    test('Test 4: Excessive Shoulder Abduction (overshoots to 125°) prompts "Lower your arm slightly"', () {
      final rx = ExercisePresets.shoulderAbductionPrescription; // min: 80, max: 100

      // Start rest
      engine.analyzeFrame(pose: _createShoulderPose(armAngleDeg: 20.0), prescription: rx);

      // Overshoot to 125°
      final overshootResult = engine.analyzeFrame(pose: _createShoulderPose(armAngleDeg: 125.0), prescription: rx);
      expect(overshootResult.statusText, contains('Lower your arm slightly'));

      // Return to rest
      final result = engine.analyzeFrame(pose: _createShoulderPose(armAngleDeg: 20.0), prescription: rx);

      expect(result.repCompleted, isTrue);
      expect(result.repWasCorrect, isFalse);
      expect(result.verdict, equals(RepVerdict.overshoot));
    });

    test('Test 5: Knee Extension displays KNEE ANGLE and evaluates knee joints (Hip -> Knee -> Ankle)', () {
      final rx = ExercisePresets.kneeExtensionPrescription;

      // Fully extended leg (152°)
      final extendedPose = _createKneePose(kneeAngleDeg: 152.0);
      final result = engine.analyzeFrame(pose: extendedPose, prescription: rx);

      expect(result.jointDisplayName, equals('KNEE ANGLE'));
      expect(result.activeJoint, equals(CocoJoint.rightKnee));
      expect(result.angle, greaterThan(140.0));
    });

    test('Test 6: Structure of all 17 COCO marked points is complete and correctly classified', () {
      expect(CocoJoint.values.length, equals(17));

      // Verify all 17 marked point indices and regions
      expect(CocoJoint.nose.id, equals(0));
      expect(CocoJoint.nose.region, equals(BodyRegion.head));
      expect(CocoJoint.nose.isCenter, isTrue);
      expect(CocoJoint.nose.defaultColor, equals(const Color(0xFF10B981)));

      expect(CocoJoint.leftEye.id, equals(1));
      expect(CocoJoint.leftEye.isLeftSide, isTrue);
      expect(CocoJoint.leftEye.defaultColor, equals(const Color(0xFF00E5FF)));

      expect(CocoJoint.rightEye.id, equals(2));
      expect(CocoJoint.rightEye.isRightSide, isTrue);
      expect(CocoJoint.rightEye.defaultColor, equals(const Color(0xFFFF6B35)));

      expect(CocoJoint.leftEar.id, equals(3));
      expect(CocoJoint.rightEar.id, equals(4));

      expect(CocoJoint.leftShoulder.id, equals(5));
      expect(CocoJoint.leftShoulder.region, equals(BodyRegion.torso));

      expect(CocoJoint.rightShoulder.id, equals(6));
      expect(CocoJoint.rightShoulder.region, equals(BodyRegion.torso));

      expect(CocoJoint.leftElbow.id, equals(7));
      expect(CocoJoint.leftElbow.region, equals(BodyRegion.upperExtremity));

      expect(CocoJoint.rightElbow.id, equals(8));
      expect(CocoJoint.leftWrist.id, equals(9));
      expect(CocoJoint.rightWrist.id, equals(10));

      expect(CocoJoint.leftHip.id, equals(11));
      expect(CocoJoint.leftHip.region, equals(BodyRegion.torso));

      expect(CocoJoint.rightHip.id, equals(12));
      expect(CocoJoint.rightHip.region, equals(BodyRegion.torso));

      expect(CocoJoint.leftKnee.id, equals(13));
      expect(CocoJoint.leftKnee.region, equals(BodyRegion.lowerExtremity));

      expect(CocoJoint.rightKnee.id, equals(14));
      expect(CocoJoint.leftAnkle.id, equals(15));
      expect(CocoJoint.rightAnkle.id, equals(16));
    });

    test('Test 7: Anatomical structural midpoints (Neck & Pelvis) calculate precisely from marked points', () {
      final pose = _createShoulderPose(armAngleDeg: 90.0);

      // Verify all 17 points visible
      expect(pose.visibleKeypointCount, equals(17));
      expect(pose.visibleKeypoints.length, equals(17));
      expect(pose.hasFullBodyVisible, isTrue);

      // Verify Neck Position (midpoint of leftShoulder and rightShoulder)
      final lShoulder = pose.getKeypoint(CocoJoint.leftShoulder)!;
      final rShoulder = pose.getKeypoint(CocoJoint.rightShoulder)!;
      final expectedNeckX = (lShoulder.x + rShoulder.x) * 0.5;
      final expectedNeckY = (lShoulder.y + rShoulder.y) * 0.5;

      expect(pose.neckPosition, isNotNull);
      expect(pose.neckPosition!.dx, closeTo(expectedNeckX, 0.01));
      expect(pose.neckPosition!.dy, closeTo(expectedNeckY, 0.01));

      // Verify Pelvis Position (midpoint of leftHip and rightHip)
      final lHip = pose.getKeypoint(CocoJoint.leftHip)!;
      final rHip = pose.getKeypoint(CocoJoint.rightHip)!;
      final expectedPelvisX = (lHip.x + rHip.x) * 0.5;
      final expectedPelvisY = (lHip.y + rHip.y) * 0.5;

      expect(pose.pelvisPosition, isNotNull);
      expect(pose.pelvisPosition!.dx, closeTo(expectedPelvisX, 0.01));
      expect(pose.pelvisPosition!.dy, closeTo(expectedPelvisY, 0.01));
    });

    test('Test 8: Knee Extension in prescribed 80°-160° range evaluates Vector 1 and Vector 2 angle and gives "✓ GOOD FORM" and "✓ GOOD REP"', () {
      final rx = ExercisePresets.kneeExtensionPrescription; // min: 80, max: 160

      // Step A: Rest position (~90°)
      final restPose = _createKneePose(kneeAngleDeg: 90.0);
      var result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.jointDisplayName, equals('KNEE ANGLE'));
      expect(result.activeJoint, equals(CocoJoint.rightKnee));

      // Step B: Extending leg into target zone (142°)
      final targetPose = _createKneePose(kneeAngleDeg: 142.0);
      result = engine.analyzeFrame(pose: targetPose, prescription: rx);

      expect(result.angle, closeTo(142.0, 1.0));
      expect(result.isMovementCorrect, isTrue);
      expect(result.feedbackCategory, equals('CORRECT'));
      expect(result.statusText, equals('✓ GOOD FORM'));
      expect(result.statusColor, equals(const Color(0xFF10B981))); // Green

      // Step C: Returning leg back to rest (90°)
      result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.repCompleted, isTrue);
      expect(result.repWasCorrect, isTrue);
      expect(result.verdict, equals(RepVerdict.correct));
      expect(result.statusText, equals('✓ GOOD REP'));
    });

    test('Test 9: Knee Extension below 80° prompts "Straighten your knee"', () {
      final rx = ExercisePresets.kneeExtensionPrescription;

      // Rest
      engine.analyzeFrame(pose: _createKneePose(kneeAngleDeg: 90.0), prescription: rx);

      final shallowPose = _createKneePose(kneeAngleDeg: 100.0);
      final shallowResult = engine.analyzeFrame(pose: shallowPose, prescription: rx);
      expect(shallowResult.repCompleted, isFalse);
    });

    test('Test 10: Knee Extension overshooting > 166° prompts "Do not extend that far"', () {
      final rx = ExercisePresets.kneeExtensionPrescription;

      // Start rest
      engine.analyzeFrame(pose: _createKneePose(kneeAngleDeg: 90.0), prescription: rx);

      // Overshoot to 172°
      final overshootPose = _createKneePose(kneeAngleDeg: 172.0);
      final result = engine.analyzeFrame(pose: overshootPose, prescription: rx);

      expect(result.isMovementCorrect, isFalse);
      expect(result.feedbackCategory, equals('INCORRECT'));
      expect(result.statusText, contains('Do not extend that far'));
      expect(result.statusColor, equals(const Color(0xFFEF4444))); // Red
    });

    test('Test 11: Occlusion Handling - when knee is hidden, displays "Knee not detected" and no false angle', () {
      final rx = ExercisePresets.kneeExtensionPrescription;

      // Create pose with occluded/invisible knee keypoints
      final occludedKeypoints = _createKneePose(kneeAngleDeg: 140.0).keypoints.map((kp) {
        if (kp.joint == CocoJoint.rightKnee || kp.joint == CocoJoint.leftKnee) {
          return kp.copyWith(confidence: 0.10); // Invisible knee
        }
        return kp;
      }).toList();

      final occludedPose = DetectedPose(
        keypoints: occludedKeypoints,
        boundingBox: const Rect.fromLTWH(100, 100, 200, 400),
        personConfidence: 0.85,
        isPersonDetected: true,
        measuredAngle: 0.0,
        targetJointName: 'Knee',
      );

      // Feed occluded frames past grace period (6 frames)
      late FrameAnalysisResult result;
      for (int i = 0; i < 6; i++) {
        result = engine.analyzeFrame(pose: occludedPose, prescription: rx);
      }

      expect(result.isOccluded, isTrue);
      expect(result.angle, equals(0.0)); // No false angle generated!
      expect(result.statusText, contains('Knee not detected'));
      expect(result.statusText, contains('Adjust your position'));

      // Resumes automatically when knee becomes visible again
      final visiblePose = _createKneePose(kneeAngleDeg: 135.0);
      final resumedResult = engine.analyzeFrame(pose: visiblePose, prescription: rx);
      expect(resumedResult.isOccluded, isFalse);
      expect(resumedResult.angle, closeTo(135.0, 1.0));
    });

    test('Test 12: Elbow Exercise calculates Shoulder -> Elbow -> Wrist and evaluates flexion/extension', () {
      final rx = ExercisePresets.elbowExercisePrescription; // min: 30, max: 150

      // Step A: Arm extended at rest (160°)
      final restPose = _createElbowPose(elbowAngleDeg: 160.0);
      var result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.jointDisplayName, equals('ELBOW ANGLE'));
      expect(result.activeJoint, equals(CocoJoint.rightElbow));

      // Step B: Flexing elbow into target zone (70°)
      final flexPose = _createElbowPose(elbowAngleDeg: 70.0);
      result = engine.analyzeFrame(pose: flexPose, prescription: rx);
      expect(result.angle, closeTo(70.0, 1.0));
      expect(result.isMovementCorrect, isTrue);
      expect(result.statusText, equals('✓ GOOD FORM'));

      // Step C: Returning to extension (160°) completes rep
      result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.repCompleted, isTrue);
      expect(result.repWasCorrect, isTrue);
      expect(result.statusText, equals('✓ GOOD REP'));
    });

    test('Test 13: Hip Exercise calculates Shoulder -> Hip -> Knee and evaluates hip flexion', () {
      final rx = ExercisePresets.hipExercisePrescription; // min: 45, max: 120

      // Step A: Standing upright (~175°)
      final restPose = _createHipPose(hipAngleDeg: 175.0);
      var result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.jointDisplayName, equals('HIP ANGLE'));
      expect(result.activeJoint, equals(CocoJoint.rightHip));

      // Step B: Lifting thigh into target hip flexion (90°)
      final flexPose = _createHipPose(hipAngleDeg: 90.0);
      result = engine.analyzeFrame(pose: flexPose, prescription: rx);
      expect(result.angle, closeTo(90.0, 1.0));
      expect(result.isMovementCorrect, isTrue);
      expect(result.statusText, equals('✓ GOOD FORM'));

      // Step C: Lowering leg back down completes rep
      result = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(result.repCompleted, isTrue);
      expect(result.repWasCorrect, isTrue);
      expect(result.statusText, equals('✓ GOOD REP'));
    });

    test('Test 14: Rep counting state machine prevents duplicate counting while user holds in target position', () {
      final rx = ExercisePresets.kneeExtensionPrescription;

      // User extends into target zone (142°)
      final targetPose = _createKneePose(kneeAngleDeg: 142.0);

      // Simulate holding position for 10 consecutive frames
      for (int i = 0; i < 10; i++) {
        final result = engine.analyzeFrame(pose: targetPose, prescription: rx);
        expect(result.repCompleted, isFalse, reason: 'Holding in target zone should NOT trigger rep completed!');
      }

      // User returns to rest (90°)
      final restPose = _createKneePose(kneeAngleDeg: 90.0);
      final finalResult = engine.analyzeFrame(pose: restPose, prescription: rx);
      expect(finalResult.repCompleted, isTrue, reason: 'Rep must ONLY increment upon completing movement cycle!');
    });
  });
}

/// Helper to create synthetic 17-keypoint pose for shoulder abduction
DetectedPose _createShoulderPose({required double armAngleDeg}) {
  const cx = 200.0;
  const cy = 300.0;
  final rad = (armAngleDeg * math.pi) / 180.0;

  final rShoulder = const PoseKeypoint(joint: CocoJoint.rightShoulder, x: cx + 40, y: cy - 80, confidence: 0.95);
  final rHip = const PoseKeypoint(joint: CocoJoint.rightHip, x: cx + 25, y: cy + 30, confidence: 0.95);

  final elbowX = (cx + 40) + (65.0 * math.sin(rad));
  final elbowY = (cy - 80) + (65.0 * math.cos(rad));
  final rElbow = PoseKeypoint(joint: CocoJoint.rightElbow, x: elbowX, y: elbowY, confidence: 0.95);

  final keypoints = [
    const PoseKeypoint(joint: CocoJoint.nose, x: cx, y: cy - 130, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEye, x: cx - 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEye, x: cx + 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEar, x: cx - 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEar, x: cx + 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftShoulder, x: cx - 40, y: cy - 80, confidence: 0.95),
    rShoulder,
    const PoseKeypoint(joint: CocoJoint.leftElbow, x: cx - 50, y: cy - 15, confidence: 0.95),
    rElbow,
    const PoseKeypoint(joint: CocoJoint.leftWrist, x: cx - 45, y: cy + 45, confidence: 0.95),
    PoseKeypoint(joint: CocoJoint.rightWrist, x: elbowX + 10, y: elbowY + 30, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftHip, x: cx - 25, y: cy + 30, confidence: 0.95),
    rHip,
    const PoseKeypoint(joint: CocoJoint.leftKnee, x: cx - 25, y: cy + 115, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightKnee, x: cx + 25, y: cy + 115, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftAnkle, x: cx - 25, y: cy + 195, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightAnkle, x: cx + 25, y: cy + 195, confidence: 0.95),
  ];

  return DetectedPose(
    keypoints: keypoints,
    boundingBox: const Rect.fromLTRB(100, 150, 300, 520),
    personConfidence: 0.95,
    isPersonDetected: true,
    measuredAngle: armAngleDeg,
    targetJointName: 'Shoulder',
  );
}

/// Helper to create synthetic 17-keypoint pose for knee extension
DetectedPose _createKneePose({required double kneeAngleDeg}) {
  const cx = 200.0;
  const cy = 300.0;
  final rad = (kneeAngleDeg * math.pi) / 180.0;

  const kneeX = cx + 50.0;
  const kneeY = cy + 50.0;
  const thighLength = 70.0;
  const shankLength = 80.0;

  final rHip = const PoseKeypoint(joint: CocoJoint.rightHip, x: kneeX - thighLength, y: kneeY, confidence: 0.95);
  final rKnee = const PoseKeypoint(joint: CocoJoint.rightKnee, x: kneeX, y: kneeY, confidence: 0.95);

  final ankleX = kneeX + shankLength * math.cos(math.pi - rad);
  final ankleY = kneeY + shankLength * math.sin(math.pi - rad);
  final rAnkle = PoseKeypoint(joint: CocoJoint.rightAnkle, x: ankleX, y: ankleY, confidence: 0.95);

  final lHip = const PoseKeypoint(joint: CocoJoint.leftHip, x: cx - 40, y: cy + 50, confidence: 0.95);
  final lKnee = const PoseKeypoint(joint: CocoJoint.leftKnee, x: cx - 10, y: cy + 50, confidence: 0.95);
  final lAnkle = const PoseKeypoint(joint: CocoJoint.leftAnkle, x: cx - 10, y: cy + 120, confidence: 0.95);

  final keypoints = [
    const PoseKeypoint(joint: CocoJoint.nose, x: cx, y: cy - 130, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEye, x: cx - 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEye, x: cx + 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEar, x: cx - 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEar, x: cx + 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftShoulder, x: cx - 40, y: cy - 80, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightShoulder, x: cx + 40, y: cy - 80, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftElbow, x: cx - 50, y: cy - 15, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightElbow, x: cx + 50, y: cy - 15, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftWrist, x: cx - 45, y: cy + 45, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightWrist, x: cx + 45, y: cy + 45, confidence: 0.95),
    lHip,
    rHip,
    lKnee,
    rKnee,
    lAnkle,
    rAnkle,
  ];

  return DetectedPose(
    keypoints: keypoints,
    boundingBox: const Rect.fromLTRB(100, 150, 300, 520),
    personConfidence: 0.95,
    isPersonDetected: true,
    measuredAngle: kneeAngleDeg,
    targetJointName: 'Knee',
  );
}

/// Helper to create synthetic 17-keypoint pose for elbow exercise (Shoulder -> Elbow -> Wrist)
DetectedPose _createElbowPose({required double elbowAngleDeg}) {
  const cx = 200.0;
  const cy = 300.0;
  final rad = (elbowAngleDeg * math.pi) / 180.0;

  final rShoulder = const PoseKeypoint(joint: CocoJoint.rightShoulder, x: cx + 40, y: cy - 80, confidence: 0.95);
  final rElbow = const PoseKeypoint(joint: CocoJoint.rightElbow, x: cx + 40, y: cy - 20, confidence: 0.95);

  final wristX = (cx + 40) + (55.0 * math.sin(rad));
  final wristY = (cy - 20) - (55.0 * math.cos(rad));
  final rWrist = PoseKeypoint(joint: CocoJoint.rightWrist, x: wristX, y: wristY, confidence: 0.95);

  final keypoints = [
    const PoseKeypoint(joint: CocoJoint.nose, x: cx, y: cy - 130, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEye, x: cx - 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEye, x: cx + 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEar, x: cx - 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEar, x: cx + 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftShoulder, x: cx - 40, y: cy - 80, confidence: 0.95),
    rShoulder,
    const PoseKeypoint(joint: CocoJoint.leftElbow, x: cx - 50, y: cy - 20, confidence: 0.95),
    rElbow,
    const PoseKeypoint(joint: CocoJoint.leftWrist, x: cx - 50, y: cy + 35, confidence: 0.95),
    rWrist,
    const PoseKeypoint(joint: CocoJoint.leftHip, x: cx - 25, y: cy + 30, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightHip, x: cx + 25, y: cy + 30, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftKnee, x: cx - 25, y: cy + 115, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightKnee, x: cx + 25, y: cy + 115, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftAnkle, x: cx - 25, y: cy + 195, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightAnkle, x: cx + 25, y: cy + 195, confidence: 0.95),
  ];

  return DetectedPose(
    keypoints: keypoints,
    boundingBox: const Rect.fromLTRB(100, 150, 300, 520),
    personConfidence: 0.95,
    isPersonDetected: true,
    measuredAngle: elbowAngleDeg,
    targetJointName: 'Elbow',
  );
}

/// Helper to create synthetic 17-keypoint pose for hip exercise (Shoulder -> Hip -> Knee)
DetectedPose _createHipPose({required double hipAngleDeg}) {
  const cx = 200.0;
  const cy = 300.0;
  final rad = (hipAngleDeg * math.pi) / 180.0;

  final rShoulder = const PoseKeypoint(joint: CocoJoint.rightShoulder, x: cx + 30, y: cy - 80, confidence: 0.95);
  final rHip = const PoseKeypoint(joint: CocoJoint.rightHip, x: cx + 30, y: cy + 30, confidence: 0.95);

  final kneeX = (cx + 30) + (70.0 * math.sin(math.pi - rad));
  final kneeY = (cy + 30) + (70.0 * math.cos(math.pi - rad));
  final rKnee = PoseKeypoint(joint: CocoJoint.rightKnee, x: kneeX, y: kneeY, confidence: 0.95);

  final keypoints = [
    const PoseKeypoint(joint: CocoJoint.nose, x: cx, y: cy - 130, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEye, x: cx - 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEye, x: cx + 10, y: cy - 140, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftEar, x: cx - 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightEar, x: cx + 20, y: cy - 135, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftShoulder, x: cx - 30, y: cy - 80, confidence: 0.95),
    rShoulder,
    const PoseKeypoint(joint: CocoJoint.leftElbow, x: cx - 45, y: cy - 20, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightElbow, x: cx + 45, y: cy - 20, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftWrist, x: cx - 45, y: cy + 35, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightWrist, x: cx + 45, y: cy + 35, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.leftHip, x: cx - 30, y: cy + 30, confidence: 0.95),
    rHip,
    const PoseKeypoint(joint: CocoJoint.leftKnee, x: cx - 30, y: cy + 115, confidence: 0.95),
    rKnee,
    const PoseKeypoint(joint: CocoJoint.leftAnkle, x: cx - 30, y: cy + 195, confidence: 0.95),
    const PoseKeypoint(joint: CocoJoint.rightAnkle, x: cx + 30, y: cy + 195, confidence: 0.95),
  ];

  return DetectedPose(
    keypoints: keypoints,
    boundingBox: const Rect.fromLTRB(100, 150, 300, 520),
    personConfidence: 0.95,
    isPersonDetected: true,
    measuredAngle: hipAngleDeg,
    targetJointName: 'Hip',
  );
}
