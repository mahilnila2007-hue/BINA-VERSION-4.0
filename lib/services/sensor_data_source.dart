import 'dart:async';
import 'dart:math' as math;
import '../domain/models/sensor_reading.dart';
import 'exercise_analysis_engine.dart';

/// Operational mode of the sensor subsystem.
enum SensorMode {
  demo,
  realTime,
}

/// Abstract contract for physiological sensor telemetry data sources.
/// 
/// Decouples UI and exercise logic from the physical telemetry transport,
/// ensuring full isolation between simulated demonstration data and real
/// ESP32 / MAX30102 / EMG BLE hardware streams.
abstract class SensorDataSource {
  SensorMode get mode;
  Stream<SensorReading> get readingStream;
  SensorReading get currentReading;

  /// Informs the data source of the current exercise phase and kinematics
  /// so simulation mode can generate physiologically correlated biosignals.
  void updateExerciseState({
    required RepCyclePhase phase,
    required double currentAngle,
    required bool isContracting,
    double targetMinAngle = 80.0,
    double targetMaxAngle = 100.0,
  });

  void pause();
  void resume();
  void dispose();
}

/// High-fidelity simulated human physiological telemetry data source.
/// 
/// Generates continuous, physiologically realistic human biometrics:
/// - Heart Rate: 65–80 BPM (resting), 75–100 BPM (exercise), sinusoidal cardiac waveform
/// - SpO₂: 96–99% with smooth micro-fluctuations (strictly 95–100% valid range)
/// - EMG: 5–15% (resting), 20–50% (movement), 50–85% (peak contraction), smooth decay
/// - Temperature: 36.3–37.2 °C
/// 
/// Runs a continuous 150 ms loop, ensuring zero '--' or static values during DEMO MODE.
class DemoSensorDataSource implements SensorDataSource {
  @override
  SensorMode get mode => SensorMode.demo;

  final StreamController<SensorReading> _controller = StreamController<SensorReading>.broadcast();
  Timer? _ticker;

  // Simulation timeline & state
  double _time = 0.0;
  bool _isPaused = false;

  // Physiological state variables (EMA smoothed for gradual transitions)
  double _baseHr = 72.0;
  double _currentHr = 72.0;
  double _currentSpo2 = 98.0;
  double _baseEmg = 42.0;
  double _currentEmg = 42.0;
  double _temperature = 36.7;

  // Kinematic context from exercise engine
  RepCyclePhase _currentPhase = RepCyclePhase.resting;
  double _currentAngle = 0.0;
  bool _isContracting = false;
  double _targetMinAngle = 80.0;
  double _targetMaxAngle = 100.0;

  late SensorReading _latestReading;

  DemoSensorDataSource({
    Duration updateInterval = const Duration(milliseconds: 150),
    double initialHr = 72.0,
    double initialSpo2 = 98.0,
    double initialEmg = 42.0,
  }) {
    _baseHr = initialHr;
    _currentHr = initialHr;
    _currentSpo2 = initialSpo2;
    _baseEmg = initialEmg;
    _currentEmg = initialEmg;

    _latestReading = SensorReading(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      emg: _currentEmg * 10.0, // microvolts scale
      emgActivationPct: _currentEmg,
      heartRate: _currentHr.round(),
      spo2: _currentSpo2.round(),
      temperature: _temperature,
      humidity: 54.0,
      isConnected: true,
      exerciseState: 'resting',
      repetitionCount: 0,
      movementCorrectness: 'correct',
    );

    _startSimulationLoop(updateInterval);
  }

  @override
  Stream<SensorReading> get readingStream => _controller.stream;

  @override
  SensorReading get currentReading => _latestReading;

  void _startSimulationLoop(Duration interval) {
    _ticker?.cancel();
    _ticker = Timer.periodic(interval, (_) => _generateNextSample());
  }

  /// Calculates the next physiological sample using continuous mathematical models.
  void _generateNextSample() {
    if (_isPaused || _controller.isClosed) return;

    // Time increment (150ms ~= 0.15s)
    _time += 0.15;
    // Guard against floating point overflow after long runs
    if (_time > 100000.0) _time = 0.0;

    // ─────────────────────────────────────────────────────────────────────────
    // 1. HEART RATE SIMULATION (Resting: 65–80, Exercise: 75–100 BPM)
    // ─────────────────────────────────────────────────────────────────────────
    double targetHrBase;
    if (_isContracting || _currentPhase == RepCyclePhase.inTargetZone) {
      targetHrBase = 88.0; // Peak contraction cardiovascular demand
    } else if (_currentPhase == RepCyclePhase.movingOut ||
        _currentPhase == RepCyclePhase.movementReturn ||
        _currentPhase == RepCyclePhase.movementStart) {
      targetHrBase = 78.0; // Movement phase
    } else {
      // Resting phase
      targetHrBase = 71.0;
    }

    // Smooth exponential approach towards exercise target (no instant jumps)
    _baseHr += (targetHrBase - _baseHr) * 0.035;

    // Physiological waveform formula:
    // HR = base + 3 * sin(time) + 1 * sin(time * 0.3) + small physiological variation
    final hrWaveform = _baseHr +
        3.0 * math.sin(_time) +
        1.0 * math.sin(_time * 0.3) +
        0.5 * math.sin(_time * 1.8);

    // Hard bounds enforcement: 60–100 BPM
    _currentHr = hrWaveform.clamp(60.0, 100.0);

    // ─────────────────────────────────────────────────────────────────────────
    // 2. SpO₂ SIMULATION (96–99% with smooth micro-variation)
    // ─────────────────────────────────────────────────────────────────────────
    double targetSpo2Base;
    if (_isContracting || _currentPhase == RepCyclePhase.inTargetZone) {
      targetSpo2Base = 97.4; // Mild peripheral desaturation under load
    } else {
      targetSpo2Base = 98.4; // Recovery baseline
    }

    _currentSpo2 += (targetSpo2Base - _currentSpo2) * 0.025;

    // Micro-variations around base
    final spo2Waveform = _currentSpo2 +
        0.45 * math.sin(_time * 0.22) +
        0.25 * math.cos(_time * 0.65);

    // Strict validation: never 70, 80, or 110%
    final safeSpo2 = spo2Waveform.clamp(96.0, 99.0);

    // ─────────────────────────────────────────────────────────────────────────
    // 3. EMG MUSCLE ACTIVITY SIMULATION (5–15% Rest, 20–50% Move, 50–85% Active)
    // ─────────────────────────────────────────────────────────────────────────
    double targetEmgBase;
    if (_isContracting || _currentPhase == RepCyclePhase.inTargetZone) {
      // Strong contraction in target ROM: 50–85%
      targetEmgBase = 68.0;
    } else if (_currentPhase == RepCyclePhase.movingOut ||
        _currentPhase == RepCyclePhase.movementReturn ||
        _currentPhase == RepCyclePhase.movementStart) {
      // Active movement / mild contraction: 20–50%
      targetEmgBase = 35.0;
    } else {
      // Resting / relaxation: 5–15%
      // Include an autonomous cyclic wave (every ~6-8 seconds) so on a static
      // test desk or preview screen, the demo continuously demonstrates
      // living contraction peaks and relaxation troughs.
      final cycle = (math.sin(_time * 0.75) + 1.0) / 2.0; // 0.0 -> 1.0
      if (cycle > 0.7) {
        // Simulated micro-contraction pulse
        targetEmgBase = 12.0 + (cycle - 0.7) * 45.0; // Rises into 25%
      } else {
        targetEmgBase = 9.5; // Natural baseline muscle tone (5–15%)
      }
    }

    // Smooth exponential filter for muscle recruitment / derecruitment
    final emgSmoothingFactor = _isContracting ? 0.22 : 0.12;
    _baseEmg += (targetEmgBase - _baseEmg) * emgSmoothingFactor;

    // Physiological motor-unit recruitment noise (EMG interference pattern)
    final emgNoise = 2.4 * math.sin(_time * 4.3) +
        1.5 * math.sin(_time * 9.1) +
        0.8 * math.cos(_time * 17.5);

    final rawEmg = _baseEmg + emgNoise;
    // Strict clamp: 5% to 85% normal exercise range (safe 0–100%)
    _currentEmg = rawEmg.clamp(5.0, 88.0);

    // ─────────────────────────────────────────────────────────────────────────
    // 4. TEMPERATURE (36.3–37.2 °C)
    // ─────────────────────────────────────────────────────────────────────────
    _temperature = 36.6 + 0.15 * math.sin(_time * 0.05);

    // Construct valid reading snapshot
    _latestReading = SensorReading(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      emg: _currentEmg * 10.0,
      emgActivationPct: _currentEmg,
      heartRate: _currentHr.round(),
      spo2: safeSpo2.round(),
      temperature: double.parse(_temperature.toStringAsFixed(1)),
      humidity: 52.0 + 1.5 * math.sin(_time * 0.1),
      isConnected: true,
      kneeAngle: _currentAngle,
      exerciseState: _currentPhase.name,
      repetitionCount: 0,
      movementCorrectness: _isContracting ? 'correct' : 'resting',
    );

    if (!_controller.isClosed) {
      _controller.add(_latestReading);
    }
  }

  @override
  void updateExerciseState({
    required RepCyclePhase phase,
    required double currentAngle,
    required bool isContracting,
    double targetMinAngle = 80.0,
    double targetMaxAngle = 100.0,
  }) {
    _currentPhase = phase;
    _currentAngle = currentAngle;
    _isContracting = isContracting;
    _targetMinAngle = targetMinAngle;
    _targetMaxAngle = targetMaxAngle;
  }

  @override
  void pause() {
    _isPaused = true;
  }

  @override
  void resume() {
    _isPaused = false;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _controller.close();
  }
}

/// Real hardware telemetry data source interface for ESP32, BLE, and wearable sensors.
/// 
/// When real sensors are disconnected or absent, it emits disconnected state with
/// `isConnected: false`, allowing the UI to render disconnected indicators ('--').
/// When hardware connects, it receives live telemetry packets and pushes real readings.
class RealSensorDataSource implements SensorDataSource {
  @override
  SensorMode get mode => SensorMode.realTime;

  final StreamController<SensorReading> _controller = StreamController<SensorReading>.broadcast();
  SensorReading _latestReading = SensorReading.disconnected();
  bool _isHardwareConnected = false;

  RealSensorDataSource() {
    _latestReading = SensorReading.disconnected();
  }

  @override
  Stream<SensorReading> get readingStream => _controller.stream;

  @override
  SensorReading get currentReading => _latestReading;

  bool get isHardwareConnected => _isHardwareConnected;

  /// Ingests a raw hardware sensor telemetry packet received from ESP32 / BLE.
  void ingestHardwarePacket({
    required int heartRate,
    required int spo2,
    required double emgActivationPct,
    required double emgRaw,
    double temperature = 36.6,
    double humidity = 50.0,
    double kneeAngle = 0.0,
  }) {
    _isHardwareConnected = true;
    _latestReading = SensorReading(
      timestamp: DateTime.now().millisecondsSinceEpoch,
      emg: emgRaw,
      emgActivationPct: emgActivationPct.clamp(0.0, 100.0),
      heartRate: heartRate.clamp(40, 220),
      spo2: spo2.clamp(70, 100),
      temperature: temperature,
      humidity: humidity,
      isConnected: true,
      kneeAngle: kneeAngle,
    );

    if (!_controller.isClosed) {
      _controller.add(_latestReading);
    }
  }

  /// Sets the hardware connection state to disconnected.
  void markDisconnected() {
    _isHardwareConnected = false;
    _latestReading = SensorReading.disconnected();
    if (!_controller.isClosed) {
      _controller.add(_latestReading);
    }
  }

  @override
  void updateExerciseState({
    required RepCyclePhase phase,
    required double currentAngle,
    required bool isContracting,
    double targetMinAngle = 80.0,
    double targetMaxAngle = 100.0,
  }) {
    // In real hardware mode, physical bio-potentials and optical PPG are measured
    // directly by sensors; kinematics are merged into the payload.
  }

  @override
  void pause() {}

  @override
  void resume() {}

  @override
  void dispose() {
    _controller.close();
  }
}
