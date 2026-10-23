import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/constants/exercise_presets.dart';
import 'package:rehabrep/domain/models/rep_verdict.dart';
import 'package:rehabrep/domain/models/repetition_data.dart';
import 'package:rehabrep/domain/models/session_record.dart';

void main() {
  group('Repetition & Form Evaluation Logic Tests', () {
    test('Correct Knee Extension within prescribed ROM (80°-160°)', () {
      final rep = RepetitionData(
        repNumber: 1,
        peakAngle: 145.0,
        duration: 2.3,
        verdict: RepVerdict.correct,
        emgActivation: 78.0,
        timestamp: DateTime.now(),
      );

      expect(rep.isCorrect, isTrue);
      expect(rep.verdict.displayName, 'GOOD REP');
      expect(rep.verdict.voiceCue, 'Good rep');
    });

    test('Shallow Knee Extension below minimum threshold', () {
      final rep = RepetitionData(
        repNumber: 2,
        peakAngle: 68.0,
        duration: 2.1,
        verdict: RepVerdict.tooShallow,
        emgActivation: 60.0,
        timestamp: DateTime.now(),
      );

      expect(rep.isCorrect, isFalse);
      expect(rep.verdict.displayName, 'BEND A LITTLE MORE');
      expect(rep.verdict.voiceCue, 'Bend a little more');
    });

    test('Overshoot Knee Extension exceeding safety limit', () {
      final rep = RepetitionData(
        repNumber: 3,
        peakAngle: 172.0,
        duration: 2.5,
        verdict: RepVerdict.overshoot,
        emgActivation: 82.0,
        timestamp: DateTime.now(),
      );

      expect(rep.isCorrect, isFalse);
      expect(rep.verdict.displayName, "DON'T BEND THAT FAR");
      expect(rep.verdict.voiceCue, "Don't bend that far");
    });

    test('SessionRecord adherence and duration formatting', () {
      final session = SessionRecord(
        id: 'test_session_1',
        patientId: 'patient_arun_001',
        exercise: ExercisePresets.kneeExtensionId,
        exerciseName: 'Seated Knee Extension',
        startTime: DateTime.now(),
        durationSeconds: 272, // 04:32
        prescribedReps: 30,
        completedReps: 30,
        correctReps: 26,
        incorrectReps: 4,
        adherence: 86.67,
        averageAngle: 143.0,
        repetitions: [],
      );

      expect(session.formattedDuration, '04:32');
      expect(session.adherence.toStringAsFixed(0), '87');
      expect(session.correctReps, 26);
    });
  });
}
