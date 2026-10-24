import '../../domain/models/prescription.dart';

/// Supported exercise definitions and clinical presets for ReHabRep.
class ExercisePresets {
  // Exercise Identifiers
  static const String fingerExerciseId = 'finger_exercise';
  static const String legExerciseId = 'leg_exercise';
  static const String handExerciseId = 'hand_exercise';
  static const String hipExerciseId = 'hip_exercise';
  static const String elbowExerciseId = 'elbow_exercise';
  static const String kneeExerciseId = 'knee_exercise';
  static const String kneeExtensionId = 'knee_extension';
  static const String shoulderAbductionId = 'shoulder_abduction';

  // 1. Finger Exercise -> YouTube: CWW0n16QCcA
  static const Prescription fingerExercisePrescription = Prescription(
    id: 'rx_finger_001',
    patientId: 'patient_arun_001',
    exerciseId: fingerExerciseId,
    exerciseName: 'Finger Exercise',
    minAngle: 0.0,
    maxAngle: 90.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Morning',
    cameraInstructions:
        'Place phone on table facing your hand. Keep hand and fingers clearly in view.',
    targetJointName: 'Fingers',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=CWW0n16QCcA',
    instructions:
        '1. Rest your palm flat on a table.\n2. Gently lift each finger upward one by one.\n3. Hold for 2 seconds.\n4. Slowly lower back down.',
    targetMuscle: 'Flexor Digitorum',
  );

  // 2. Leg Exercise -> YouTube: 1kVUlwHzGso
  static const Prescription legExercisePrescription = Prescription(
    id: 'rx_leg_001',
    patientId: 'patient_arun_001',
    exerciseId: legExerciseId,
    exerciseName: 'Leg Exercise',
    minAngle: 0.0,
    maxAngle: 45.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Morning',
    cameraInstructions:
        'Place phone 6–8 feet away. Stand or lie down with full leg in frame.',
    targetJointName: 'Leg',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=1kVUlwHzGso',
    instructions:
        '1. Lie on your back or sit upright.\n2. Keep your leg straight.\n3. Slowly raise your leg upwards.\n4. Hold for 2 seconds then lower smoothly.',
    targetMuscle: 'Hamstrings & Calves',
  );

  // 3. Hand Exercise -> YouTube: XIpa7NtedwM
  static const Prescription handExercisePrescription = Prescription(
    id: 'rx_hand_001',
    patientId: 'patient_arun_001',
    exerciseId: handExerciseId,
    exerciseName: 'Hand Exercise',
    minAngle: 0.0,
    maxAngle: 90.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Afternoon',
    cameraInstructions:
        'Place phone at chest level facing your hand and wrist.',
    targetJointName: 'Wrist & Hand',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=XIpa7NtedwM',
    instructions:
        '1. Open your hand wide.\n2. Slowly make a gentle fist.\n3. Hold for 2 seconds.\n4. Slowly open and stretch fingers.',
    targetMuscle: 'Wrist Extensors & Flexors',
  );

  // 4. Hip Exercise -> YouTube: pCsuDA5W_9g
  static const Prescription hipExercisePrescription = Prescription(
    id: 'rx_hip_001',
    patientId: 'patient_arun_001',
    exerciseId: hipExerciseId,
    exerciseName: 'Hip Exercise',
    minAngle: 45.0,
    maxAngle: 120.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Morning',
    cameraInstructions:
        'Place phone 6–8 feet away at side view showing hips and knees.',
    targetJointName: 'Hip',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=pCsuDA5W_9g',
    instructions:
        '1. Stand holding a stable support or lie flat.\n2. Extend your hip backward or lift knee to chest.\n3. Hold for 2 seconds.\n4. Return smoothly to starting position.',
    targetMuscle: 'Gluteus Maximus & Hip Flexors',
  );

  // 5. Elbow Exercise -> YouTube: 3RhAXHRvrKI
  static const Prescription elbowExercisePrescription = Prescription(
    id: 'rx_elbow_001',
    patientId: 'patient_arun_001',
    exerciseId: elbowExerciseId,
    exerciseName: 'Elbow Exercise',
    minAngle: 30.0,
    maxAngle: 150.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Afternoon',
    cameraInstructions:
        'Place phone 4–6 feet away. Keep shoulder, elbow, and wrist clearly visible.',
    targetJointName: 'Elbow',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=3RhAXHRvrKI',
    instructions:
        '1. Sit or stand upright with arm at your side.\n2. Bend elbow to bring hand toward shoulder.\n3. Hold contraction for 2 seconds.\n4. Slowly straighten elbow back down.',
    targetMuscle: 'Biceps & Triceps',
  );

  // 6. Knee Exercise -> YouTube: hw_yl3qmO88
  static const Prescription kneeExercisePrescription = Prescription(
    id: 'rx_knee_001',
    patientId: 'patient_arun_001',
    exerciseId: kneeExerciseId,
    exerciseName: 'Knee Exercise',
    minAngle: 80.0,
    maxAngle: 160.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Morning & Evening',
    cameraInstructions:
        'Place phone 6–8 feet away at side angle. Sit on a firm chair with hip, knee, and ankle clearly visible.',
    targetJointName: 'Knee',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=hw_yl3qmO88',
    instructions:
        '1. Sit upright on a stable chair with back supported.\n2. Keep your thigh resting on the seat.\n3. Slowly extend your knee until your lower leg is straight.\n4. Hold the top contraction for 2 seconds.\n5. Lower your leg slowly back down to 90° under control.',
    targetMuscle: 'Quadriceps',
  );

  // Backward compatibility presets
  static const Prescription kneeExtensionPrescription = Prescription(
    id: 'rx_knee_001',
    patientId: 'patient_arun_001',
    exerciseId: kneeExtensionId,
    exerciseName: 'Knee Exercise',
    minAngle: 80.0,
    maxAngle: 160.0,
    sets: 3,
    reps: 10,
    schedule: 'Daily - Morning & Evening',
    cameraInstructions:
        'Place phone 6–8 feet away at side angle. Sit on a firm chair with hip, knee, and ankle clearly visible.',
    targetJointName: 'Knee',
    trainingVideoUrl: 'https://www.youtube.com/watch?v=hw_yl3qmO88',
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

  /// All 6 prescribed rehabilitation exercises with verified YouTube video mappings.
  static List<Prescription> get allPresets => [
        fingerExercisePrescription,
        legExercisePrescription,
        handExercisePrescription,
        hipExercisePrescription,
        elbowExercisePrescription,
        kneeExercisePrescription,
      ];

  /// Resolves an exercise preset by its identifier with resilient fallback.
  static Prescription getById(String exerciseId) {
    for (final p in allPresets) {
      if (p.exerciseId == exerciseId) return p;
    }
    if (exerciseId == kneeExtensionId) return kneeExtensionPrescription;
    if (exerciseId == shoulderAbductionId) return shoulderAbductionPrescription;
    return kneeExercisePrescription;
  }
}
