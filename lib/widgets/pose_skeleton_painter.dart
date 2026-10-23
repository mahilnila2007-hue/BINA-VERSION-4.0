import 'package:flutter/material.dart';
import '../domain/models/detected_pose.dart';
import '../domain/models/pose_keypoint.dart';

/// Minimal, clinical-grade joint tracking overlay.
/// 
/// Strictly adheres to:
/// - NO cyan bounding box
/// - NO full artificial skeleton
/// - NO floating head or irrelevant body points
/// - NO angle arc or mathematical construction
/// - ONLY thin green tracking lines along relevant active joints (Hip -> Knee -> Ankle or Shoulder -> Elbow -> Wrist)
/// - ONLY small green circular joint markers (with active knee slightly larger)
/// - Clean "Knee 90°" text readout beside the knee
/// - Minimal, unobtrusive confidence indicator
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

  // Clinical Green Palette
  static const Color trackingGreen = Color(0xFF00E676); // High-visibility medical green
  static const Color darkOverlayBg = Color(0xCC0B1220);

  @override
  void paint(Canvas canvas, Size size) {
    // If no person detected or keypoints empty, show NOTHING on camera
    if (!pose.isPersonDetected || pose.keypoints.isEmpty) return;

    final isShoulder = exerciseId == 'shoulder_abduction';

    if (isShoulder) {
      _drawArmTracking(canvas);
    } else {
      _drawKneeExtensionTracking(canvas);
    }

    // Display clean joint angle label close to the active joint: "Knee 90°"
    // No angle arc or mathematical construction
    if (!isOccluded && measuredAngle > 0.0) {
      _drawCleanAngleLabel(canvas, isShoulder: isShoulder);
    }

    // Minimal pose confidence indicator in top-right corner of camera frame
    _drawMinimalConfidence(canvas, size);
  }

  /// Knee Extension: Prioritizes ONLY HIP -> KNEE -> ANKLE
  void _drawKneeExtensionTracking(Canvas canvas) {
    final isRight = activeJoint == CocoJoint.rightKnee;
    final hipJoint = isRight ? CocoJoint.rightHip : CocoJoint.leftHip;
    final kneeJoint = isRight ? CocoJoint.rightKnee : CocoJoint.leftKnee;
    final ankleJoint = isRight ? CocoJoint.rightAnkle : CocoJoint.leftAnkle;

    final hip = pose.getKeypoint(hipJoint);
    final knee = pose.getKeypoint(kneeJoint);
    final ankle = pose.getKeypoint(ankleJoint);

    // 1. Thin green tracking lines along relevant joints
    final linePaint = Paint()
      ..color = trackingGreen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    if (hip != null && knee != null && hip.isVisible && knee.isVisible && !isOccluded) {
      canvas.drawLine(hip.position, knee.position, linePaint);
    }

    if (knee != null && ankle != null && knee.isVisible && ankle.isVisible && !isOccluded) {
      canvas.drawLine(knee.position, ankle.position, linePaint);
    }

    // 2. Small green circular joint markers
    // Hip marker: Small green circle (radius 3.6)
    if (hip != null && hip.isVisible) {
      _drawJointCircle(canvas, hip.position, radius: 3.6, isPrimary: false);
    }

    // Ankle marker: Small green circle (radius 3.6)
    if (ankle != null && ankle.isVisible) {
      _drawJointCircle(canvas, ankle.position, radius: 3.6, isPrimary: false);
    }

    // Knee marker: Slightly larger than the others (radius 5.6)
    if (knee != null && knee.isVisible && !isOccluded) {
      _drawJointCircle(canvas, knee.position, radius: 5.6, isPrimary: true);
    }
  }

  /// Hand / Arm Exercises: Prioritizes SHOULDER -> ELBOW -> WRIST
  void _drawArmTracking(Canvas canvas) {
    final isRight = activeJoint == CocoJoint.rightShoulder;
    final shoulderJoint = isRight ? CocoJoint.rightShoulder : CocoJoint.leftShoulder;
    final elbowJoint = isRight ? CocoJoint.rightElbow : CocoJoint.leftElbow;
    final wristJoint = isRight ? CocoJoint.rightWrist : CocoJoint.leftWrist;

    final shoulder = pose.getKeypoint(shoulderJoint);
    final elbow = pose.getKeypoint(elbowJoint);
    final wrist = pose.getKeypoint(wristJoint);

    final linePaint = Paint()
      ..color = trackingGreen
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;

    if (shoulder != null && elbow != null && shoulder.isVisible && elbow.isVisible) {
      canvas.drawLine(shoulder.position, elbow.position, linePaint);
    }

    if (elbow != null && wrist != null && elbow.isVisible && wrist.isVisible) {
      canvas.drawLine(elbow.position, wrist.position, linePaint);
    }

    if (shoulder != null && shoulder.isVisible) {
      _drawJointCircle(canvas, shoulder.position, radius: 3.6, isPrimary: false);
    }
    if (wrist != null && wrist.isVisible) {
      _drawJointCircle(canvas, wrist.position, radius: 3.6, isPrimary: false);
    }
    if (elbow != null && elbow.isVisible) {
      _drawJointCircle(canvas, elbow.position, radius: 5.6, isPrimary: true);
    }
  }

  /// Draws a clean, solid small green circular joint marker
  void _drawJointCircle(Canvas canvas, Offset center, {required double radius, required bool isPrimary}) {
    if (isPrimary) {
      // Subtle pulse halo
      final haloPaint = Paint()
        ..color = trackingGreen.withValues(alpha: 0.25 * (1.0 - pulseValue))
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius + 4.0 + (pulseValue * 3.0), haloPaint);
    }

    // Solid green circle
    final circlePaint = Paint()
      ..color = trackingGreen
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, circlePaint);

    // Tiny white center dot for precision focus
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, isPrimary ? 2.0 : 1.4, dotPaint);
  }

  /// Displays the calculated angle close to the active joint: "Knee 90°"
  /// NO angle arc or mathematical construction.
  void _drawCleanAngleLabel(Canvas canvas, {required bool isShoulder}) {
    final jointNode = pose.getKeypoint(activeJoint);
    if (jointNode == null || !jointNode.isVisible) return;

    final center = jointNode.position;
    final label = isShoulder ? 'Arm' : 'Knee';

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label ${measuredAngle.toStringAsFixed(0)}°',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Position label slightly offset from the knee marker
    final labelOffset = Offset(center.dx + 12, center.dy - 12);

    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        labelOffset.dx - 5,
        labelOffset.dy - 3,
        textPainter.width + 10,
        textPainter.height + 6,
      ),
      const Radius.circular(5),
    );

    // Clean, translucent black pill with green hairline
    final bgPaint = Paint()
      ..color = darkOverlayBg
      ..style = PaintingStyle.fill;
    canvas.drawRRect(bgRect, bgPaint);

    final borderPaint = Paint()
      ..color = trackingGreen.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bgRect, borderPaint);

    textPainter.paint(canvas, labelOffset);
  }

  /// Minimal pose confidence indicator: subtle small chip in corner
  void _drawMinimalConfidence(Canvas canvas, Size size) {
    final confPercent = (pose.personConfidence * 100).toInt().clamp(0, 100);

    final textPainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '● ',
            style: TextStyle(
              color: trackingGreen,
              fontSize: 9,
            ),
          ),
          TextSpan(
            text: 'POSE $confPercent%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width - textPainter.width - 18, 12, textPainter.width + 10, textPainter.height + 6),
      const Radius.circular(4),
    );

    final bgPaint = Paint()
      ..color = const Color(0x99000000)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(chipRect, bgPaint);

    textPainter.paint(canvas, Offset(size.width - textPainter.width - 13, 15));
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
