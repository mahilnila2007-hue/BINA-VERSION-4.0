import '../../domain/models/patient.dart';
import '../local/session_local_db.dart';

class PatientRepository {
  final SessionLocalDb _localDb;

  PatientRepository(this._localDb);

  List<Patient> getAllPatients() {
    return _localDb.getPatients();
  }

  Patient? getPatient(String id) {
    return _localDb.getPatientById(id);
  }

  Future<void> savePatient(Patient patient) {
    return _localDb.savePatient(patient);
  }
}
