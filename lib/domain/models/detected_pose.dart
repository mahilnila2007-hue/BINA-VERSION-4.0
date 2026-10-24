import 'package:flutter/material.dart';
import 'pose_keypoint.dart';

/// Complete detected pose for a single camera frame from YOLO Pose.
class DetectedPose {
  final List<PoseKeypoint> keypoints;
  final Rect boundingBox;
  final double personConfidence;
  final bool isPersonDetected;
  final double measuredAngle;
  final String targetJointName;

  const DetectedPose({
    required this.keypoints,
    required this.boundingBox,
    required this.personConfidence,
    required this.isPersonDetected,
    required this.measuredAngle,
    required this.targetJointName,
  });

  /// Map of all keypoints by joint enum for O(1) lookup
  Map<CocoJoint, PoseKeypoint> get keypointMap {
    final map = <CocoJoint, PoseKeypoint>{};
    for (final kp in keypoints) {
      map[kp.joint] = kp;
    }
    return map;
  }

  /// Helper to fetch keypoint by joint enum
  PoseKeypoint? getKeypoint(CocoJoint joint) {
    for (final kp in keypoints) {
      if (kp.joint == joint) return kp;
    }
    return null;
  }

  /// Returns joint position if visible (confidence >= 0.35)
  Offset? getJointPosition(CocoJoint joint) {
    final kp = getKeypoint(joint);
    if (kp != null && kp.isVisible) {
      return kp.position;
    }
    return null;
  }

  /// Calculates anatomical midpoint between two joints if both are visible
  Offset? getMidpoint(CocoJoint j1, CocoJoint j2) {
    final p1 = getJointPosition(j1);
    final p2 = getJointPosition(j2);
    if (p1 != null && p2 != null) {
      return Offset((p1.dx + p2.dx) * 0.5, (p1.dy + p2.dy) * 0.5);
    }
    return null;
  }

  /// Anatomical Neck / Sternal Notch: midpoint of Left and Right Shoulders
  Offset? get neckPosition => getMidpoint(CocoJoint.leftShoulder, CocoJoint.rightShoulder);

  /// Anatomical Pelvis Center: midpoint of Left and Right Hips
  Offset? get pelvisPosition => getMidpoint(CocoJoint.leftHip, CocoJoint.rightHip);

  /// Returns all keypoints currently above visibility threshold
  List<PoseKeypoint> get visibleKeypoints =>
      keypoints.where((kp) => kp.isVisible).toList();

  /// Total count of visible keypoints out of 17
  int get visibleKeypointCount =>
      keypoints.where((kp) => kp.isVisible).length;

  // Check if knee extension required joints are visible (Hip, Knee, Ankle)
  bool get hasKneeJointsVisible {
    final hip = getKeypoint(CocoJoint.leftHip) ?? getKeypoint(CocoJoint.rightHip);
    final knee = getKeypoint(CocoJoint.leftKnee) ?? getKeypoint(CocoJoint.rightKnee);
    final ankle = getKeypoint(CocoJoint.leftAnkle) ?? getKeypoint(CocoJoint.rightAnkle);

    return (hip?.isVisible ?? false) &&
        (knee?.isVisible ?? false) &&
        (ankle?.isVisible ?? false);
  }

  // Check if shoulder abduction required joints are visible
  bool get hasShoulderJointsVisible {
    final hip = getKeypoint(CocoJoint.leftHip) ?? getKeypoint(CocoJoint.rightHip);
    final shoulder = getKeypoint(CocoJoint.leftShoulder) ?? getKeypoint(CocoJoint.rightShoulder);
    final elbow = getKeypoint(CocoJoint.leftElbow) ?? getKeypoint(CocoJoint.rightElbow);

    return (hip?.isVisible ?? false) &&
        (shoulder?.isVisible ?? false) &&
        (elbow?.isVisible ?? false);
  }

  // Check if elbow exercise required joints are visible (Shoulder, Elbow, Wrist)
  bool get hasElbowJointsVisible {
    final shoulder = getKeypoint(CocoJoint.leftShoulder) ?? getKeypoint(CocoJoint.rightShoulder);
    final elbow = getKeypoint(CocoJoint.leftElbow) ?? getKeypoint(CocoJoint.rightElbow);
    final wrist = getKeypoint(CocoJoint.leftWrist) ?? getKeypoint(CocoJoint.rightWrist);

    return (shoulder?.isVisible ?? false) &&
        (elbow?.isVisible ?? false) &&
        (wrist?.isVisible ?? false);
  }

  // Check if hip exercise required joints are visible (Shoulder, Hip, Knee)
  bool get hasHipJointsVisible {
    final shoulder = getKeypoint(CocoJoint.leftShoulder) ?? getKeypoint(CocoJoint.rightShoulder);
    final hip = getKeypoint(CocoJoint.leftHip) ?? getKeypoint(CocoJoint.rightHip);
    final knee = getKeypoint(CocoJoint.leftKnee) ?? getKeypoint(CocoJoint.rightKnee);

    return (shoulder?.isVisible ?? false) &&
        (hip?.isVisible ?? false) &&
        (knee?.isVisible ?? false);
  }

  // Check if full body is generally in frame
  bool get isFullBodyInFrame {
    final head = getKeypoint(CocoJoint.nose);
    final hip = getKeypoint(CocoJoint.leftHip) ?? getKeypoint(CocoJoint.rightHip);
    final ankle = getKeypoint(CocoJoint.leftAnkle) ?? getKeypoint(CocoJoint.rightAnkle);

    return (head?.isVisible ?? false) &&
        (hip?.isVisible ?? false) &&
        (ankle?.isVisible ?? false);
  }

  bool get hasFullBodyVisible => isFullBodyInFrame;

  // Factory for empty/no-person frame
  factory DetectedPose.empty() => const DetectedPose(
        keypoints: [],
        boundingBox: Rect.zero,
        personConfidence: 0.0,
        isPersonDetected: false,
        measuredAngle: 0.0,
        targetJointName: '',
      );
}

