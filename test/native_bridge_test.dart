import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/domain/models/rep_verdict.dart';
import 'package:rehabrep/native/ffi/native_engine_bridge.dart';

void main() {
  group('NativeEngineBridge Algorithm Tests', () {
    final bridge = NativeEngineBridge();

    test('calculateJointAngle computes 90 and 180 degrees correctly', () {
      final angle90 = bridge.calculateJointAngle(0.0, 10.0, 0.0, 0.0, 10.0, 0.0);
      expect(angle90, closeTo(90.0, 0.01));

      final angle180 = bridge.calculateJointAngle(0.0, 10.0, 0.0, 0.0, 0.0, -10.0);
      expect(angle180, closeTo(180.0, 0.01));
    });

    test('smoothAngle applies EMA formula', () {
      final smoothed = bridge.smoothAngle(150.0, 140.0, alpha: 0.35);
      final expected = (0.35 * 150.0) + (0.65 * 140.0);
      expect(smoothed, closeTo(expected, 0.001));
    });

    test('calculateEmgRms and normalizeEmgActivation', () {
      final rms = bridge.calculateEmgRms([10.0, -10.0, 10.0, -10.0]);
      expect(rms, closeTo(10.0, 0.01));

      final act = bridge.normalizeEmgActivation(rms, 20.0);
      expect(act, closeTo(50.0, 0.01));
    });

    test('evaluateRepetition correctly classifies shallow and correct reps', () {
      final correct = bridge.evaluateRepetition(
        peakAngle: 150.0,
        minAngle: 80.0,
        maxAngle: 160.0,
        durationSeconds: 2.4,
        emgActivationPct: 75.0,
      );
      expect(correct, RepVerdict.correct);

      final shallow = bridge.evaluateRepetition(
        peakAngle: 100.0, // below 80 + (80 * 0.65) = 132
        minAngle: 80.0,
        maxAngle: 160.0,
        durationSeconds: 2.2,
        emgActivationPct: 60.0,
      );
      expect(shallow, RepVerdict.tooShallow);
    });
  });
}
