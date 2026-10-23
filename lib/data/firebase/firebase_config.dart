/// Firebase Configuration and Endpoint schema for ReHabRep.
/// Follows database architecture defined in Section 22:
/// users/, patients/, therapists/, prescriptions/, sessions/, sensor_data/
class FirebaseConfig {
  static const String projectId = 'rehabrep-ai-mvp';
  static const String databaseUrl = 'https://rehabrep-ai-mvp-default-rtdb.firebaseio.com';

  // Collection paths
  static const String colUsers = 'users';
  static const String colPatients = 'patients';
  static const String colTherapists = 'therapists';
  static const String colPrescriptions = 'prescriptions';
  static const String colSessions = 'sessions';
  static const String colSensorData = 'sensor_data';

  // Cloud Functions endpoints
  static const String fnSummarizeSession = 'summarizeSession';
}
