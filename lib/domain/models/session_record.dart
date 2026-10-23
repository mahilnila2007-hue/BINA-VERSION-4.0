import 'repetition_data.dart';

/// Complete session report for a physiotherapy exercise session.
/// Persisted locally offline, synced to Firebase when online.
class SessionRecord {
  final String id;
  final String patientId;
  final String exercise;
  final String exerciseName;
  final DateTime startTime;
  final int durationSeconds;
  final int prescribedReps;
  final int completedReps;
  final int correctReps;
  final int incorrectReps;
  final double adherence; // 0-100%
  final double averageAngle;
  final int maxHR;
  final int minSpO2;
  final double temperature;
  final double humidity;
  final double averageEmg;
  final double peakEmg;
  final List<RepetitionData> repetitions;
  final bool isSynced;
  final String? aiSummary;

  const SessionRecord({
    required this.id,
    required this.patientId,
    required this.exercise,
    required this.exerciseName,
    required this.startTime,
    required this.durationSeconds,
    required this.prescribedReps,
    required this.completedReps,
    required this.correctReps,
    required this.incorrectReps,
    required this.adherence,
    required this.averageAngle,
    this.maxHR = 0,
    this.minSpO2 = 0,
    this.temperature = 0.0,
    this.humidity = 0.0,
    this.averageEmg = 0.0,
    this.peakEmg = 0.0,
    required this.repetitions,
    this.isSynced = false,
    this.aiSummary,
  });

  String get formattedDuration {
    final minutes = (durationSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (durationSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  SessionRecord copyWith({
    bool? isSynced,
    String? aiSummary,
  }) {
    return SessionRecord(
      id: id,
      patientId: patientId,
      exercise: exercise,
      exerciseName: exerciseName,
      startTime: startTime,
      durationSeconds: durationSeconds,
      prescribedReps: prescribedReps,
      completedReps: completedReps,
      correctReps: correctReps,
      incorrectReps: incorrectReps,
      adherence: adherence,
      averageAngle: averageAngle,
      maxHR: maxHR,
      minSpO2: minSpO2,
      temperature: temperature,
      humidity: humidity,
      averageEmg: averageEmg,
      peakEmg: peakEmg,
      repetitions: repetitions,
      isSynced: isSynced ?? this.isSynced,
      aiSummary: aiSummary ?? this.aiSummary,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'patientId': patientId,
        'exercise': exercise,
        'exerciseName': exerciseName,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'prescribedReps': prescribedReps,
        'completedReps': completedReps,
        'correctReps': correctReps,
        'incorrectReps': incorrectReps,
        'adherence': adherence,
        'averageAngle': averageAngle,
        'maxHR': maxHR,
        'minSpO2': minSpO2,
        'temperature': temperature,
        'humidity': humidity,
        'averageEmg': averageEmg,
        'peakEmg': peakEmg,
        'repetitions': repetitions.map((r) => r.toJson()).toList(),
        'isSynced': isSynced,
        'aiSummary': aiSummary,
      };

  factory SessionRecord.fromJson(Map<String, dynamic> json) => SessionRecord(
        id: json['id'] as String,
        patientId: json['patientId'] as String,
        exercise: json['exercise'] as String,
        exerciseName: json['exerciseName'] as String,
        startTime: DateTime.parse(json['startTime'] as String),
        durationSeconds: json['durationSeconds'] as int,
        prescribedReps: json['prescribedReps'] as int,
        completedReps: json['completedReps'] as int,
        correctReps: json['correctReps'] as int,
        incorrectReps: json['incorrectReps'] as int,
        adherence: (json['adherence'] as num).toDouble(),
        averageAngle: (json['averageAngle'] as num).toDouble(),
        maxHR: (json['maxHR'] as num?)?.toInt() ?? 0,
        minSpO2: (json['minSpO2'] as num?)?.toInt() ?? 0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
        averageEmg: (json['averageEmg'] as num?)?.toDouble() ?? 0.0,
        peakEmg: (json['peakEmg'] as num?)?.toDouble() ?? 0.0,
        repetitions: (json['repetitions'] as List<dynamic>?)
                ?.map((r) => RepetitionData.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        isSynced: json['isSynced'] as bool? ?? false,
        aiSummary: json['aiSummary'] as String?,
      );
}
