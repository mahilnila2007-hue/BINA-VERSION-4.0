import '../../domain/models/prescription.dart';
import '../local/session_local_db.dart';

class PrescriptionRepository {
  final SessionLocalDb _localDb;

  PrescriptionRepository(this._localDb);

  List<Prescription> getPrescriptions() {
    return _localDb.getPrescriptions();
  }

  Prescription? getPrescriptionForPatient(String patientId, {String? exerciseId}) {
    return _localDb.getPrescriptionForPatient(patientId, exerciseId: exerciseId);
  }

  Future<void> savePrescription(Prescription rx) {
    return _localDb.savePrescription(rx);
  }
}
