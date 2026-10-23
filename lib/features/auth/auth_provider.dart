import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../data/firebase/firebase_auth_service.dart';
import '../../data/firebase/mock_firebase_service.dart';
import '../../data/local/session_local_db.dart';
import '../../data/repositories/patient_repository.dart';
import '../../data/repositories/prescription_repository.dart';
import '../../data/repositories/session_repository.dart';
import '../../domain/models/patient.dart';
import '../../domain/models/prescription.dart';
import '../../domain/models/session_record.dart';
import '../../domain/models/user_profile.dart';

// Database Provider
final sessionLocalDbProvider = Provider<SessionLocalDb>((ref) {
  throw UnimplementedError('Database must be initialized in main()');
});

// Firebase Auth Service Provider
final firebaseAuthServiceProvider = Provider<FirebaseAuthService>((ref) {
  throw UnimplementedError('FirebaseAuthService must be initialized in main()');
});

// Firebase Cloud Sync Provider
final firebaseSyncServiceProvider = Provider<FirebaseSyncService>((ref) {
  return FirebaseSyncService();
});

// Repositories
final patientRepositoryProvider = Provider<PatientRepository>((ref) {
  return PatientRepository(ref.watch(sessionLocalDbProvider));
});

final prescriptionRepositoryProvider = Provider<PrescriptionRepository>((ref) {
  return PrescriptionRepository(ref.watch(sessionLocalDbProvider));
});

final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  return SessionRepository(
    ref.watch(sessionLocalDbProvider),
    ref.watch(firebaseSyncServiceProvider),
  );
});

// Current Authenticated User Provider
class CurrentUserNotifier extends Notifier<UserProfile?> {
  @override
  UserProfile? build() {
    final authService = ref.watch(firebaseAuthServiceProvider);
    return authService.currentUser;
  }

  void setUser(UserProfile? user) {
    state = user;
  }

  Future<void> updatePreferences({
    bool? voiceCoaching,
    bool? haptics,
    bool? isFrontCamera,
  }) async {
    if (state == null) return;
    final updated = state!.copyWith(
      voiceCoachingEnabled: voiceCoaching,
      hapticFeedbackEnabled: haptics,
      isFrontCamera: isFrontCamera,
    );
    state = updated;
    await ref.read(firebaseAuthServiceProvider).updateProfile(updated);
  }

  Future<void> signOut() async {
    await ref.read(firebaseAuthServiceProvider).signOut();
    state = null;
  }
}

final currentUserProvider =
    NotifierProvider<CurrentUserNotifier, UserProfile?>(CurrentUserNotifier.new);

// Authenticated state check
final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(currentUserProvider) != null;
});

// Firebase Auth State Changes Stream Provider
final authStateChangesProvider = StreamProvider<UserProfile?>((ref) {
  final authService = ref.watch(firebaseAuthServiceProvider);
  return authService.authStateChanges;
});

// Current Patient Id mapped to current user
final currentPatientIdProvider = Provider<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.id ?? AppConstants.defaultPatientId;
});

// Current Active Prescription for patient
class CurrentPrescriptionNotifier extends Notifier<Prescription?> {
  @override
  Prescription? build() {
    final patientId = ref.watch(currentPatientIdProvider);
    final repo = ref.watch(prescriptionRepositoryProvider);
    return repo.getPrescriptionForPatient(patientId);
  }

  void setPrescription(Prescription rx) => state = rx;
}

final currentPrescriptionProvider =
    NotifierProvider<CurrentPrescriptionNotifier, Prescription?>(CurrentPrescriptionNotifier.new);

// Current Patient data
final currentPatientProvider = Provider<Patient?>((ref) {
  final patientId = ref.watch(currentPatientIdProvider);
  final repo = ref.watch(patientRepositoryProvider);
  return repo.getPatient(patientId);
});

// Patient Sessions List
class PatientSessionsNotifier extends Notifier<List<SessionRecord>> {
  @override
  List<SessionRecord> build() {
    final patientId = ref.watch(currentPatientIdProvider);
    final repo = ref.watch(sessionRepositoryProvider);
    return repo.getSessionsForPatient(patientId);
  }

  void refresh() {
    final patientId = ref.read(currentPatientIdProvider);
    final repo = ref.read(sessionRepositoryProvider);
    state = repo.getSessionsForPatient(patientId);
  }

  Future<void> addSession(SessionRecord session) async {
    final repo = ref.read(sessionRepositoryProvider);
    final recorded = await repo.recordSession(session);
    state = [recorded, ...state.where((s) => s.id != recorded.id)];
  }
}

final patientSessionsProvider =
    NotifierProvider<PatientSessionsNotifier, List<SessionRecord>>(PatientSessionsNotifier.new);

// Online/Offline status
class OnlineStatusNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
    ref.read(firebaseSyncServiceProvider).setOnlineStatus(state);
  }
}

final isOnlineProvider =
    NotifierProvider<OnlineStatusNotifier, bool>(OnlineStatusNotifier.new);
