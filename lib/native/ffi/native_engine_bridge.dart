import 'dart:math' as math;
import '../../domain/models/rep_verdict.dart';

/// Dart FFI Bridge & Pure-Dart Fallback for Native C++ RepEngine.
/// Implements the exact same computational interface exposed by native/include/rep_engine.h:
/// - joint_angle()
/// - smooth_angle()
/// - rep_engine_update()
/// - emg_rms()
class NativeEngineBridge {
  static final NativeEngineBridge _instance = NativeEngineBridge._internal();
  factory NativeEngineBridge() => _instance;
  NativeEngineBridge._internal();

  /// Calculates joint angle formed by three 2D keypoints (A -> B -> C)
  /// Returns angle in degrees [0.0, 180.0].
  double calculateJointAngle(
    double ax, double ay,
    double bx, double by,
    double cx, double cy,
  ) {
    final v1x = ax - bx;
    final v1y = ay - by;
    final v2x = cx - bx;
    final v2y = cy - by;

    final dot = (v1x * v2x) + (v1y * v2y);
    final mag1 = math.sqrt((v1x * v1x) + (v1y * v1y));
    final mag2 = math.sqrt((v2x * v2x) + (v2y * v2y));

    if (mag1 < 1e-5 || mag2 < 1e-5) return 0.0;

    var cosine = dot / (mag1 * mag2);
    if (cosine > 1.0) cosine = 1.0;
    if (cosine < -1.0) cosine = -1.0;

    final radians = math.acos(cosine);
    return radians * (180.0 / math.pi);
  }

  /// Exponential Moving Average (EMA) smoothing for angle time series.
  double smoothAngle(double currentRaw, double previousSmoothed, {double alpha = 0.35}) {
    if (previousSmoothed <= 0.0) return currentRaw;
    return (alpha * currentRaw) + ((1.0 - alpha) * previousSmoothed);
  }

  /// Calculates Root Mean Square of EMG samples.
  double calculateEmgRms(List<double> samples) {
    if (samples.isEmpty) return 0.0;
    double sumSquares = 0.0;
    for (final s in samples) {
      sumSquares += (s * s);
    }
    return math.sqrt(sumSquares / samples.length);
  }

  /// Normalizes EMG RMS against Maximum Voluntary Contraction (MVC).
  double normalizeEmgActivation(double currentRms, double mvcRms) {
    if (mvcRms <= 1e-4) return 0.0;
    final pct = (currentRms / mvcRms) * 100.0;
    return pct.clamp(0.0, 100.0);
  }

  /// Evaluates movement against prescribed ROM limits.
  RepVerdict evaluateRepetition({
    required double peakAngle,
    required double minAngle,
    required double maxAngle,
    required double durationSeconds,
    required double emgActivationPct,
  }) {
    if (durationSeconds < 1.2) {
      return RepVerdict.tooFast;
    }
    final shallowThreshold = minAngle + (maxAngle - minAngle) * 0.65;
    if (peakAngle < shallowThreshold) {
      return RepVerdict.tooShallow;
    }
    if (peakAngle > maxAngle + 6.0) {
      return RepVerdict.overshoot;
    }
    if (emgActivationPct > 0.0 && emgActivationPct < 28.0) {
      return RepVerdict.lowMuscleEngagement;
    }
    return RepVerdict.correct;
  }
}
