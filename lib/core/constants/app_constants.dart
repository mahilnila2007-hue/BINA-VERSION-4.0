/// Global application constants for ReHabRep.
class AppConstants {
  static const String appName = 'ReHabRep';
  static const String appTagline = 'Intelligent Home Physiotherapy Form Coach';
  static const String disclaimerText =
      'Supports rehabilitation monitoring. Designed to assist physiotherapy adherence. Not intended for autonomous medical diagnosis.';

  // Default patient & therapist IDs for demo
  static const String defaultPatientId = 'patient_arun_001';
  static const String defaultTherapistId = 'therapist_priya_001';

  // State machine hysteresis & timing thresholds
  static const double defaultHysteresisDegrees = 4.0;
  static const double minRepDurationSeconds = 1.2;
  static const double maxRepDurationSeconds = 7.0;

  // Voice feedback cooldown
  static const int voiceCooldownSeconds = 3;

  // AI inference input dimensions
  static const int modelInputSize = 320;
}
