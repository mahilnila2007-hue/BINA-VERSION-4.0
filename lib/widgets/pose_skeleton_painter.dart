import 'package:flutter/material.dart';
import '../core/theme/color_palette.dart';
import '../domain/models/detected_pose.dart';
import '../domain/models/pose_keypoint.dart';

/// Professional, clinical-grade YOLO Pose 17-Keypoint Skeleton Overlay.
/// 
/// Renders:
/// - 17 Human Body Keypoint Circles (Head, Shoulders, Elbows, Wrists, Hips, Knees, Ankles)
/// - Anatomical Skeleton Connection Lines
/// - Person Bounding Box with Detection Confidence
/// - Active Exercise Joint Highlight with Dynamic Pulsing Ring
/// - Clean Joint Angle Readout (e.g. "Knee Angle: 142°")
class PoseSkeletonPainter extends CustomPainter {
  final DetectedPose pose;
  final double pulseValue;
  final double measuredAngle;
  final double minPrescribedAngle;
  final double maxPrescribedAngle;
  final String exerciseId;
  final CocoJoint activeJoint;
  final bool isMovementCorrect;
  final bool isOccluded;

  PoseSkeletonPainter({
    required this.pose,
    required this.pulseValue,
    required this.measuredAngle,
    this.minPrescribedAngle = 80.0,
    this.maxPrescribedAngle = 100.0,
    this.exerciseId = 'knee_extension',
    this.activeJoint = CocoJoint.rightKnee,
    this.isMovementCorrect = false,
    this.isOccluded = false,
  });

  // Color Palette
  static const Color cyanTracking = Color(0xFF00E5FF);
  static const Color orangeTracking = Color(0xFFFF6B35);
  static const Color greenTracking = Color(0xFF00E676);
  static const Color activeHaloGreen = Color(0x5500E676);
  static const Color activeHaloOrange = Color(0x55FF6B35);

  // Standard 19 COCO Anatomical Connections
  static const List<List<CocoJoint>> _skeletonConnections = [
    // Head / Facial
    [CocoJoint.nose, CocoJoint.leftEye],
    [CocoJoint.nose, CocoJoint.rightEye],
    [CocoJoint.leftEye, CocoJoint.leftEar],
    [CocoJoint.rightEye, CocoJoint.rightEar],

    // Torso / Collar
    [CocoJoint.leftShoulder, CocoJoint.rightShoulder],
    [CocoJoint.leftShoulder, CocoJoint.leftHip],
    [CocoJoint.rightShoulder, CocoJoint.rightHip],
    [CocoJoint.leftHip, CocoJoint.rightHip],

    // Left Arm
    [CocoJoint.leftShoulder, CocoJoint.leftElbow],
    [CocoJoint.leftElbow, CocoJoint.leftWrist],

    // Right Arm
    [CocoJoint.rightShoulder, CocoJoint.rightElbow],
    [CocoJoint.rightElbow, CocoJoint.rightWrist],

    // Left Leg
    [CocoJoint.leftHip, CocoJoint.leftKnee],
    [CocoJoint.leftKnee, CocoJoint.leftAnkle],

    // Right Leg
    [CocoJoint.rightHip, CocoJoint.rightKnee],
    [CocoJoint.rightKnee, CocoJoint.rightAnkle],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (!pose.isPersonDetected || pose.keypoints.isEmpty) return;

    final keypointMap = pose.keypointMap;

    // 1. Draw Person Bounding Box if detected
    _drawBoundingBox(canvas);

    // 2. Draw Skeleton Connection Lines
    _drawSkeletonConnections(canvas, keypointMap);

    // 3. Draw All 17 Keypoint Circles
    _drawKeypointCircles(canvas);

    // 4. Draw Active Joint Angle Readout beside active joint
    if (!isOccluded && measuredAngle > 0.0) {
      _drawActiveJointAngleLabel(canvas, keypointMap);
    }
  }

  /// Draws person bounding box with confidence badge
  void _drawBoundingBox(Canvas canvas) {
    final box = pose.boundingBox;
    if (box == Rect.zero || box.width <= 10 || box.height <= 10) return;

    final boxPaint = Paint()
      ..color = (isMovementCorrect ? greenTracking : cyanTracking).withValues(alpha: 0.40)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final rrect = RRect.fromRectAndRadius(box, const Radius.circular(10));
    canvas.drawRRect(rrect, boxPaint);

    // Corner brackets accent
    final cornerPaint = Paint()
      ..color = isMovementCorrect ? greenTracking : cyanTracking
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;

    const cornerLen = 14.0;
    // Top-Left
    canvas.drawLine(box.topLeft, box.topLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(box.topLeft, box.topLeft + const Offset(0, cornerLen), cornerPaint);
    // Top-Right
    canvas.drawLine(box.topRight, box.topRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(box.topRight, box.topRight + const Offset(0, cornerLen), cornerPaint);
    // Bottom-Left
    canvas.drawLine(box.bottomLeft, box.bottomLeft + const Offset(cornerLen, 0), cornerPaint);
    canvas.drawLine(box.bottomLeft, box.bottomLeft + const Offset(0, -cornerLen), cornerPaint);
    // Bottom-Right
    canvas.drawLine(box.bottomRight, box.bottomRight + const Offset(-cornerLen, 0), cornerPaint);
    canvas.drawLine(box.bottomRight, box.bottomRight + const Offset(0, -cornerLen), cornerPaint);

    // Confidence Tag Pill at top of bounding box
    final confPercent = (pose.personConfidence * 100).toInt().clamp(0, 100);
    final confText = 'PERSON $confPercent%';
    final textPainter = TextPainter(
      text: TextSpan(
        text: confText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final badgeOffset = Offset(box.left + 8, (box.top - 18).clamp(8.0, double.infinity));
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(badgeOffset.dx - 4, badgeOffset.dy - 2, textPainter.width + 8, textPainter.height + 4),
      const Radius.circular(4),
    );

    final badgeBgPaint = Paint()
      ..color = const Color(0xCC0B1220)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(badgeRect, badgeBgPaint);

    textPainter.paint(canvas, badgeOffset);
  }

  /// Draws 19 COCO anatomical connection lines
  void _drawSkeletonConnections(Canvas canvas, Map<CocoJoint, PoseKeypoint> keypointMap) {
    for (final connection in _skeletonConnections) {
      final j1 = connection[0];
      final j2 = connection[1];

      final p1 = keypointMap[j1];
      final p2 = keypointMap[j2];

      if (p1 == null || p2 == null || !p1.isVisible || !p2.isVisible) continue;

      final bool isActiveLimb = _isConnectionActive(j1, j2);

      final linePaint = Paint()
        ..color = isActiveLimb
            ? (isMovementCorrect ? greenTracking : orangeTracking)
            : cyanTracking.withValues(alpha: 0.65)
        ..strokeWidth = isActiveLimb ? 3.4 : 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(p1.position, p2.position, linePaint);
    }
  }

  /// Determines if a skeleton segment is part of the currently targeted exercise limb
  bool _isConnectionActive(CocoJoint j1, CocoJoint j2) {
    if (activeJoint == CocoJoint.rightKnee || activeJoint == CocoJoint.leftKnee) {
      final isRight = activeJoint == CocoJoint.rightKnee;
      if (isRight) {
        return (j1 == CocoJoint.rightHip && j2 == CocoJoint.rightKnee) ||
            (j1 == CocoJoint.rightKnee && j2 == CocoJoint.rightAnkle);
      } else {
        return (j1 == CocoJoint.leftHip && j2 == CocoJoint.leftKnee) ||
            (j1 == CocoJoint.leftKnee && j2 == CocoJoint.leftAnkle);
      }
    }

    if (activeJoint == CocoJoint.rightElbow || activeJoint == CocoJoint.leftElbow) {
      final isRight = activeJoint == CocoJoint.rightElbow;
      if (isRight) {
        return (j1 == CocoJoint.rightShoulder && j2 == CocoJoint.rightElbow) ||
            (j1 == CocoJoint.rightElbow && j2 == CocoJoint.rightWrist);
      } else {
        return (j1 == CocoJoint.leftShoulder && j2 == CocoJoint.leftElbow) ||
            (j1 == CocoJoint.leftElbow && j2 == CocoJoint.leftWrist);
      }
    }

    if (activeJoint == CocoJoint.rightShoulder || activeJoint == CocoJoint.leftShoulder) {
      final isRight = activeJoint == CocoJoint.rightShoulder;
      if (isRight) {
        return (j1 == CocoJoint.rightHip && j2 == CocoJoint.rightShoulder) ||
            (j1 == CocoJoint.rightShoulder && j2 == CocoJoint.rightElbow);
      } else {
        return (j1 == CocoJoint.leftHip && j2 == CocoJoint.leftShoulder) ||
            (j1 == CocoJoint.leftShoulder && j2 == CocoJoint.leftElbow);
      }
    }

    if (activeJoint == CocoJoint.rightHip || activeJoint == CocoJoint.leftHip) {
      final isRight = activeJoint == CocoJoint.rightHip;
      if (isRight) {
        return (j1 == CocoJoint.rightShoulder && j2 == CocoJoint.rightHip) ||
            (j1 == CocoJoint.rightHip && j2 == CocoJoint.rightKnee);
      } else {
        return (j1 == CocoJoint.leftShoulder && j2 == CocoJoint.leftHip) ||
            (j1 == CocoJoint.leftHip && j2 == CocoJoint.leftKnee);
      }
    }

    return false;
  }

  /// Draws circles for all 17 human joints with special active joint pulsing
  void _drawKeypointCircles(Canvas canvas) {
    for (final kp in pose.keypoints) {
      if (!kp.isVisible) continue;

      final isTargetJoint = kp.joint == activeJoint;
      final center = kp.position;

      if (isTargetJoint) {
        // Dynamic Pulsing Halo on Active Joint
        final haloPaint = Paint()
          ..color = (isMovementCorrect ? activeHaloGreen : activeHaloOrange)
              .withValues(alpha: (1.0 - pulseValue).clamp(0.1, 0.6))
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 7.0 + (pulseValue * 8.0), haloPaint);

        // Active outer ring
        final ringPaint = Paint()
          ..color = isMovementCorrect ? greenTracking : orangeTracking
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4;
        canvas.drawCircle(center, 6.2, ringPaint);

        // Core fill
        final corePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 3.2, corePaint);
      } else {
        // Standard Joint Circle
        final circlePaint = Paint()
          ..color = kp.color
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 4.0, circlePaint);

        // White Center Dot
        final dotPaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 1.8, dotPaint);
      }
    }
  }

  /// Displays the measured angle label close to the active joint (e.g. "Knee Angle: 142°")
  void _drawActiveJointAngleLabel(Canvas canvas, Map<CocoJoint, PoseKeypoint> keypointMap) {
    final activeKp = keypointMap[activeJoint];
    if (activeKp == null || !activeKp.isVisible) return;

    final center = activeKp.position;
    final jointName = _resolveJointDisplayName(activeJoint);

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$jointName Angle\n',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: '${measuredAngle.toStringAsFixed(0)}°',
            style: TextStyle(
              color: isMovementCorrect ? greenTracking : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    // Position label slightly offset from the active marker
    final labelOffset = Offset(center.dx + 16, center.dy - 20);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - 6,
        labelOffset.dy - 4,
        textPainter.width + 12,
        textPainter.height + 8,
      ),
      const Radius.circular(8),
    );

    // Dark high-contrast translucent pill
    final bgPaint = Paint()
      ..color = const Color(0xDD0B1220)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = (isMovementCorrect ? greenTracking : AppColors.primaryLight).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRRect(bgRect, borderPaint);

    textPainter.paint(canvas, labelOffset);
  }

  String _resolveJointDisplayName(CocoJoint joint) {
    switch (joint) {
      case CocoJoint.leftKnee:
      case CocoJoint.rightKnee:
        return 'Knee';
      case CocoJoint.leftElbow:
      case CocoJoint.rightElbow:
        return 'Elbow';
      case CocoJoint.leftShoulder:
      case CocoJoint.rightShoulder:
        return 'Shoulder';
      case CocoJoint.leftHip:
      case CocoJoint.rightHip:
        return 'Hip';
      case CocoJoint.leftWrist:
      case CocoJoint.rightWrist:
        return 'Wrist';
      default:
        return joint.label;
    }
  }

  @override
  bool shouldRepaint(covariant PoseSkeletonPainter oldDelegate) {
    return oldDelegate.measuredAngle != measuredAngle ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.pose.isPersonDetected != pose.isPersonDetected ||
        oldDelegate.activeJoint != activeJoint ||
        oldDelegate.isMovementCorrect != isMovementCorrect ||
        oldDelegate.isOccluded != isOccluded ||
        oldDelegate.pose.personConfidence != pose.personConfidence;
  }
}
