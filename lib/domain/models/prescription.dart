/// Prescribed physical therapy movement protocol created by therapist.
class Prescription {
  final String id;
  final String patientId;
  final String exerciseId; // 'knee_extension' | 'shoulder_abduction'
  final String exerciseName;
  final double minAngle; // e.g. 80.0
  final double maxAngle; // e.g. 160.0
  final int sets; // e.g. 3
  final int reps; // e.g. 10 or 15
  final String schedule; // e.g. 'Daily - Morning'
  final String cameraInstructions;
  final String targetJointName;
  final String trainingVideoUrl;
  final String instructions;
  final String targetMuscle;

  const Prescription({
    required this.id,
    required this.patientId,
    required this.exerciseId,
    required this.exerciseName,
    required this.minAngle,
    required this.maxAngle,
    required this.sets,
    required this.reps,
    required this.schedule,
    required this.cameraInstructions,
    required this.targetJointName,
    this.trainingVideoUrl = 'https://www.youtube.com/watch?v=yYJ4m2L-4Jg',
    this.instructions = 'Sit upright on a stable chair. Slowly extend your lower leg upward until straight, hold for 2 seconds, then return under control.',
    this.targetMuscle = 'Quadriceps',
  });

  int get totalPrescribedReps => sets * reps;

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'exerciseId': exerciseId,
        'exerciseName': exerciseName,
        'minAngle': minAngle,
        'maxAngle': maxAngle,
        'sets': sets,
        'reps': reps,
        'schedule': schedule,
        'cameraInstructions': cameraInstructions,
        'targetJointName': targetJointName,
        'trainingVideoUrl': trainingVideoUrl,
        'instructions': instructions,
        'targetMuscle': targetMuscle,
      };

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        exerciseId: json['exerciseId'] as String,
        exerciseName: json['exerciseName'] as String,
        minAngle: (json['minAngle'] as num).toDouble(),
        maxAngle: (json['maxAngle'] as num).toDouble(),
        sets: json['sets'] as int,
        reps: json['reps'] as int,
        schedule: json['schedule'] as String,
        cameraInstructions: (json['cameraInstructions'] as String?) ??
            'Keep your whole body inside the frame.',
        targetJointName: (json['targetJointName'] as String?) ?? 'Target Joint',
        trainingVideoUrl: (json['trainingVideoUrl'] as String?) ??
            'https://www.youtube.com/watch?v=yYJ4m2L-4Jg',
        instructions: (json['instructions'] as String?) ??
            'Perform movement smoothly through the prescribed range.',
        targetMuscle: (json['targetMuscle'] as String?) ?? 'Primary Muscle',
      );
}
