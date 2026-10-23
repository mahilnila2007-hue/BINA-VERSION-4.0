import 'rep_verdict.dart';

/// Recorded data for a single repetition in an exercise session.
class RepetitionData {
  final int repNumber;
  final double peakAngle;
  final double duration; // in seconds
  final RepVerdict verdict;
  final double emgActivation; // 0-100% normalized
  final DateTime timestamp;

  const RepetitionData({
    required this.repNumber,
    required this.peakAngle,
    required this.duration,
    required this.verdict,
    this.emgActivation = 0.0,
    required this.timestamp,
  });

  bool get isCorrect => verdict == RepVerdict.correct;

  Map<String, dynamic> toJson() => {
        'repNumber': repNumber,
        'peakAngle': peakAngle,
        'duration': duration,
        'verdict': verdict.name.toUpperCase(),
        'emgActivation': emgActivation,
        'timestamp': timestamp.toIso8601String(),
      };

  factory RepetitionData.fromJson(Map<String, dynamic> json) => RepetitionData(
        repNumber: json['repNumber'] as int,
        peakAngle: (json['peakAngle'] as num).toDouble(),
        duration: (json['duration'] as num).toDouble(),
        verdict: RepVerdict.fromString(json['verdict'] as String),
        emgActivation: (json['emgActivation'] as num?)?.toDouble() ?? 0.0,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
