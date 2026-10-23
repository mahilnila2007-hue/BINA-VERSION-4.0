import 'package:flutter/material.dart';

/// Body region classification for COCO joints.
enum BodyRegion {
  head,
  torso,
  upperExtremity,
  lowerExtremity,
}

/// 17 COCO Keypoint definitions for YOLO Pose architecture.
enum CocoJoint {
  nose(0, 'Nose', 'NOSE', BodyRegion.head),
  leftEye(1, 'Left Eye', 'L.EYE', BodyRegion.head),
  rightEye(2, 'Right Eye', 'R.EYE', BodyRegion.head),
  leftEar(3, 'Left Ear', 'L.EAR', BodyRegion.head),
  rightEar(4, 'Right Ear', 'R.EAR', BodyRegion.head),
  leftShoulder(5, 'Left Shoulder', 'L.SHL', BodyRegion.torso),
  rightShoulder(6, 'Right Shoulder', 'R.SHL', BodyRegion.torso),
  leftElbow(7, 'Left Elbow', 'L.ELB', BodyRegion.upperExtremity),
  rightElbow(8, 'Right Elbow', 'R.ELB', BodyRegion.upperExtremity),
  leftWrist(9, 'Left Wrist', 'L.WRS', BodyRegion.upperExtremity),
  rightWrist(10, 'Right Wrist', 'R.WRS', BodyRegion.upperExtremity),
  leftHip(11, 'Left Hip', 'L.HIP', BodyRegion.torso),
  rightHip(12, 'Right Hip', 'R.HIP', BodyRegion.torso),
  leftKnee(13, 'Left Knee', 'L.KNE', BodyRegion.lowerExtremity),
  rightKnee(14, 'Right Knee', 'R.KNE', BodyRegion.lowerExtremity),
  leftAnkle(15, 'Left Ankle', 'L.ANK', BodyRegion.lowerExtremity),
  rightAnkle(16, 'Right Ankle', 'R.ANK', BodyRegion.lowerExtremity);

  final int id;
  final String label;
  final String abbreviatedLabel;
  final BodyRegion region;

  const CocoJoint(this.id, this.label, this.abbreviatedLabel, this.region);

  bool get isLeftSide =>
      this == leftEye ||
      this == leftEar ||
      this == leftShoulder ||
      this == leftElbow ||
      this == leftWrist ||
      this == leftHip ||
      this == leftKnee ||
      this == leftAnkle;

  bool get isRightSide =>
      this == rightEye ||
      this == rightEar ||
      this == rightShoulder ||
      this == rightElbow ||
      this == rightWrist ||
      this == rightHip ||
      this == rightKnee ||
      this == rightAnkle;

  bool get isCenter => this == nose;

  /// Clinical HUD color differentiation for marked points
  Color get defaultColor {
    if (isLeftSide) {
      return const Color(0xFF00E5FF); // Electric Cyan
    } else if (isRightSide) {
      return const Color(0xFFFF6B35); // ReHabRep Radiant Orange
    } else {
      return const Color(0xFF10B981); // Emerald Green
    }
  }
}

/// Represents an individual 2D joint coordinate predicted by YOLO Pose.
class PoseKeypoint {
  final CocoJoint joint;
  final double x; // Pixel coordinates on viewport
  final double y;
  final double normalizedX; // 0.0 to 1.0
  final double normalizedY; // 0.0 to 1.0
  final double confidence; // 0.0 to 1.0

  const PoseKeypoint({
    required this.joint,
    required this.x,
    required this.y,
    this.normalizedX = 0.0,
    this.normalizedY = 0.0,
    required this.confidence,
  });

  bool get isVisible => confidence >= 0.35;

  Offset get position => Offset(x, y);

  Color get color => joint.defaultColor;

  PoseKeypoint copyWith({
    double? x,
    double? y,
    double? normalizedX,
    double? normalizedY,
    double? confidence,
  }) {
    return PoseKeypoint(
      joint: joint,
      x: x ?? this.x,
      y: y ?? this.y,
      normalizedX: normalizedX ?? this.normalizedX,
      normalizedY: normalizedY ?? this.normalizedY,
      confidence: confidence ?? this.confidence,
    );
  }
}
