import '../../domain/models/session_record.dart';
import '../firebase/mock_firebase_service.dart';
import '../local/session_local_db.dart';

class SessionRepository {
  final SessionLocalDb _localDb;
  final FirebaseSyncService _firebaseService;

  SessionRepository(this._localDb, this._firebaseService);

  List<SessionRecord> getSessionsForPatient(String patientId) {
    return _localDb.getSessions(patientId: patientId);
  }

  SessionRecord? getLatestSession(String patientId) {
    final list = getSessionsForPatient(patientId);
    return list.isNotEmpty ? list.first : null;
  }

  /// Saves session locally first (offline-first).
  /// Then attempts background sync to Firebase if online.
  Future<SessionRecord> recordSession(SessionRecord session) async {
    // 1. Local persistence immediately
    await _localDb.saveSession(session);

    // 2. Generate AI summary
    final aiSummary = await _firebaseService.generateAiSummary(session);
    var updatedSession = session.copyWith(aiSummary: aiSummary);

    // 3. Sync to Firebase
    final didSync = await _firebaseService.syncSession(updatedSession);
    if (didSync) {
      updatedSession = updatedSession.copyWith(isSynced: true);
      await _localDb.saveSession(updatedSession);
      await _localDb.clearSyncItem(updatedSession.id);
    }

    return updatedSession;
  }

  /// Syncs any outstanding items in the offline queue
  Future<int> syncPendingSessions() async {
    final queue = _localDb.getSyncQueue();
    int syncedCount = 0;
    for (final id in queue) {
      final sessions = _localDb.getSessions();
      final session = sessions.cast<SessionRecord?>().firstWhere((s) => s?.id == id, orElse: () => null);
      if (session != null) {
        final success = await _firebaseService.syncSession(session);
        if (success) {
          await _localDb.clearSyncItem(id);
          syncedCount++;
        }
      }
    }
    return syncedCount;
  }
}
