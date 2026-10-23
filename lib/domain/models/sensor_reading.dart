/// Bio-signal and environmental telemetry received from BINA sensor suite + ESP32 wearable hub.
/// Fully integrates visual kinematics (Knee Angle, Pose Confidence, Repetition Count, Movement Correctness)
/// with physiological telemetry: EEG, EMG, GSR, IMU, MAX30102 (HR/SpO2), and DHT22 (Temp/Humidity).
class SensorReading {
  final int timestamp;
  final double emg; // RMS or raw microvolts
  final double emgActivationPct; // 0–100% normalized against MVC
  final int heartRate; // BPM (MAX30102)
  final int spo2; // % (MAX30102)
  final double temperature; // °C (DHT22)
  final double humidity; // % (DHT22)
  final double eeg; // µV (EEG neural focus)
  final double gsr; // µS (Galvanic Skin Response)
  final double imuPitch; // Degrees (IMU pitch)
  final double imuRoll; // Degrees (IMU roll)
  final double imuYaw; // Degrees (IMU yaw)
  final bool isConnected;

  // Visual Kinematics from YOLO Pose
  final double kneeAngle;
  final double poseConfidence; // 0.0 - 1.0
  final String exerciseState; // 'resting', 'inTargetZone', 'extending', etc.
  final int repetitionCount;
  final String movementCorrectness; // 'correct', 'tooShallow', 'overshoot', etc.

  const SensorReading({
    required this.timestamp,
    required this.emg,
    required this.emgActivationPct,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.humidity,
    this.eeg = 0.0,
    this.gsr = 0.0,
    this.imuPitch = 0.0,
    this.imuRoll = 0.0,
    this.imuYaw = 0.0,
    this.isConnected = true,
    this.kneeAngle = 0.0,
    this.poseConfidence = 0.0,
    this.exerciseState = 'resting',
    this.repetitionCount = 0,
    this.movementCorrectness = 'unknown',
  });

  // Default disconnected / camera-only state
  factory SensorReading.disconnected({
    double kneeAngle = 0.0,
    double poseConfidence = 0.0,
    String exerciseState = 'resting',
    int repetitionCount = 0,
    String movementCorrectness = 'unknown',
  }) =>
      SensorReading(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        emg: 0.0,
        emgActivationPct: 0.0,
        heartRate: 0,
        spo2: 0,
        temperature: 0.0,
        humidity: 0.0,
        eeg: 0.0,
        gsr: 0.0,
        imuPitch: 0.0,
        imuRoll: 0.0,
        imuYaw: 0.0,
        isConnected: false,
        kneeAngle: kneeAngle,
        poseConfidence: poseConfidence,
        exerciseState: exerciseState,
        repetitionCount: repetitionCount,
        movementCorrectness: movementCorrectness,
      );

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'emg': emg,
        'emgActivationPct': emgActivationPct,
        'heartRate': heartRate,
        'spo2': spo2,
        'temperature': temperature,
        'humidity': humidity,
        'eeg': eeg,
        'gsr': gsr,
        'imuPitch': imuPitch,
        'imuRoll': imuRoll,
        'imuYaw': imuYaw,
        'isConnected': isConnected,
        'kneeAngle': kneeAngle,
        'poseConfidence': poseConfidence,
        'exerciseState': exerciseState,
        'repetitionCount': repetitionCount,
        'movementCorrectness': movementCorrectness,
      };

  factory SensorReading.fromJson(Map<String, dynamic> json) => SensorReading(
        timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        emg: (json['emg'] as num?)?.toDouble() ?? 0.0,
        emgActivationPct: (json['emgActivationPct'] as num?)?.toDouble() ?? 0.0,
        heartRate: (json['heartRate'] as num?)?.toInt() ?? 0,
        spo2: (json['spo2'] as num?)?.toInt() ?? 0,
        temperature: (json['temperature'] as num?)?.toDouble() ?? 0.0,
        humidity: (json['humidity'] as num?)?.toDouble() ?? 0.0,
        eeg: (json['eeg'] as num?)?.toDouble() ?? 0.0,
        gsr: (json['gsr'] as num?)?.toDouble() ?? 0.0,
        imuPitch: (json['imuPitch'] as num?)?.toDouble() ?? 0.0,
        imuRoll: (json['imuRoll'] as num?)?.toDouble() ?? 0.0,
        imuYaw: (json['imuYaw'] as num?)?.toDouble() ?? 0.0,
        isConnected: json['isConnected'] as bool? ?? true,
        kneeAngle: (json['kneeAngle'] as num?)?.toDouble() ?? 0.0,
        poseConfidence: (json['poseConfidence'] as num?)?.toDouble() ?? 0.0,
        exerciseState: json['exerciseState'] as String? ?? 'resting',
        repetitionCount: (json['repetitionCount'] as num?)?.toInt() ?? 0,
        movementCorrectness: json['movementCorrectness'] as String? ?? 'unknown',
      );
}

/// Comprehensive BINA Assessment Report combining visual pose kinematics with physiological sensors.
class BinaAssessmentReport {
  final String patientId;
  final String exerciseName;
  final int totalRepetitions;
  final int correctRepetitions;
  final double averageKneeAngle;
  final double peakKneeAngle;
  final double averageConfidence;
  final double averageEmgActivation;
  final int averageHeartRate;
  final int averageSpo2;
  final double averageTemperature;
  final DateTime completionTime;

  const BinaAssessmentReport({
    required this.patientId,
    required this.exerciseName,
    required this.totalRepetitions,
    required this.correctRepetitions,
    required this.averageKneeAngle,
    required this.peakKneeAngle,
    required this.averageConfidence,
    required this.averageEmgActivation,
    required this.averageHeartRate,
    required this.averageSpo2,
    required this.averageTemperature,
    required this.completionTime,
  });

  double get accuracyScore =>
      totalRepetitions > 0 ? (correctRepetitions / totalRepetitions) * 100.0 : 100.0;
}

