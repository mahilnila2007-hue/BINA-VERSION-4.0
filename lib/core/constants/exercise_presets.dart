import '../../domain/models/prescription.dart';

/// Supported exercise definitions and clinical presets for MVP.
class ExercisePresets {
  static const String kneeExtensionId = 'knee_extension';
  static const String shoulderAbductionId = 'shoulder_abduction';

  static const Prescription kneeExtensionPrescription = Prescription(
    id: 'rx_knee_001',
    patientId: 'patient_arun_001',
    exerciseId: kneeExtensionId,
    exerciseName: 'Knee Extension',
    minAngle: 80.0,
    maxAngle: 160.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Morning & Evening',
    cameraInstructions:
        'Place phone 6–8 feet away at side angle. Sit on a firm chair with hip, knee, and ankle clearly visible.',
    targetJointName: 'Knee',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=yYJ4m2L-4Jg',
    instructions:
        '1. Sit upright on a stable chair with back supported.\n2. Keep your thigh resting on the seat.\n3. Slowly extend your knee until your lower leg is straight.\n4. Hold the top contraction for 2 seconds.\n5. Lower your leg slowly back down to 90° under control.',
    targetMuscle: 'Quadriceps',
  );

  static const Prescription shoulderAbductionPrescription = Prescription(
    id: 'rx_shoulder_001',
    patientId: 'patient_arun_001',
    exerciseId: shoulderAbductionId,
    exerciseName: 'Shoulder Abduction',
    minAngle: 80.0,
    maxAngle: 100.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Afternoon',
    cameraInstructions:
        'Place phone 6–8 feet away facing you. Stand or sit upright with torso, shoulder, and elbow clearly visible.',
    targetJointName: 'Shoulder',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=x1-0qG_WnK8',
    instructions:
        '1. Stand or sit tall with arm relaxed at your side.\n2. Keep your elbow straight and thumb pointing up.\n3. Raise your arm outward to the side up to shoulder height.\n4. Hold briefly at the apex.\n5. Slowly lower back to the starting position.',
    targetMuscle: 'Lateral Deltoid',
  );

  static List<Prescription> get allPresets => [
        kneeExtensionPrescription,
        shoulderAbductionPrescription,
      ];
}
