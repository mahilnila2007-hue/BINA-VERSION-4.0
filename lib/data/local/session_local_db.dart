import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/exercise_presets.dart';
import '../../domain/models/patient.dart';
import '../../domain/models/prescription.dart';
import '../../domain/models/rep_verdict.dart';
import '../../domain/models/repetition_data.dart';
import '../../domain/models/session_record.dart';

/// Local offline database managing sessions, prescriptions, and sync queue.
class SessionLocalDb {
  static const String _sessionsKey = 'rehabrep_local_sessions';
  static const String _prescriptionsKey = 'rehabrep_prescriptions';
  static const String _patientsKey = 'rehabrep_patients';
  static const String _syncQueueKey = 'rehabrep_sync_queue';
  static const String _initializedKey = 'rehabrep_db_initialized';

  final SharedPreferences _prefs;

  SessionLocalDb(this._prefs);

  static Future<SessionLocalDb> init() async {
    final prefs = await SharedPreferences.getInstance();
    final db = SessionLocalDb(prefs);
    await db._seedInitialDataIfFirstRun();
    return db;
  }

  /// Seeds realistic initial clinical data matching hackathon specifications.
  Future<void> _seedInitialDataIfFirstRun() async {
    final isInitialized = _prefs.getBool(_initializedKey) ?? false;
    if (isInitialized) return;

    debugPrint('Seeding initial clinical data for ReHabRep...');

    // 1. Patient: Arun (68, Knee Rehabilitation)
    final arun = Patient(
      id: AppConstants.defaultPatientId,
      name: 'Arun',
      therapistId: AppConstants.defaultTherapistId,
      age: 68,
      language: 'en',
      condition: 'Knee Rehabilitation (Post-TKR)',
      admittedDate: DateTime.now().subtract(const Duration(days: 14)),
    );
    await savePatient(arun);

    // 2. Prescriptions
    await savePrescription(ExercisePresets.kneeExtensionPrescription);
    await savePrescription(ExercisePresets.shoulderAbductionPrescription);

    // 3. Seed historical sessions (Mon -> Thu trend)
    final now = DateTime.now();

    // 3 days ago (Mon) - 72% adherence
    await saveSession(_createMockSession(
      id: 'session_hist_01',
      startTime: now.subtract(const Duration(days: 3, hours: 4)),
      durationSec: 310,
      prescribed: 30,
      completed: 26,
      correct: 21,
      adherence: 72.0,
      avgAngle: 136.0,
      avgEmg: 64.0,
      peakEmg: 82.0,
      hr: 76,
      spo2: 98,
    ));

    // 2 days ago (Tue) - 80% adherence
    await saveSession(_createMockSession(
      id: 'session_hist_02',
      startTime: now.subtract(const Duration(days: 2, hours: 3)),
      durationSec: 295,
      prescribed: 30,
      completed: 28,
      correct: 24,
      adherence: 80.0,
      avgAngle: 139.0,
      avgEmg: 69.0,
      peakEmg: 86.0,
      hr: 77,
      spo2: 98,
    ));

    // Yesterday (Wed) - 84% adherence
    await saveSession(_createMockSession(
      id: 'session_hist_03',
      startTime: now.subtract(const Duration(days: 1, hours: 5)),
      durationSec: 280,
      prescribed: 30,
      completed: 29,
      correct: 25,
      adherence: 84.0,
      avgAngle: 141.0,
      avgEmg: 71.0,
      peakEmg: 89.0,
      hr: 79,
      spo2: 97,
    ));

    // Today's morning session (Thu) - 87% adherence (matches Spec Section 24 & 25)
    await saveSession(_createMockSession(
      id: 'session_hist_04_today',
      startTime: DateTime(now.year, now.month, now.day, 10, 42),
      durationSec: 272,
      prescribed: 30,
      completed: 30,
      correct: 26,
      adherence: 87.0,
      avgAngle: 143.0,
      avgEmg: 74.0,
      peakEmg: 91.0,
      hr: 78,
      spo2: 97,
      temp: 27.0,
      hum: 61.0,
      aiSummary:
          'Patient completed 30 of 30 prescribed repetitions with 87% adherence. Notable improvement in knee flexion ROM (+4°). 3 shallow reps detected during Set 3. Muscle engagement was solid (74% avg).',
    ));

    await _prefs.setBool(_initializedKey, true);
  }

  SessionRecord _createMockSession({
    required String id,
    required DateTime startTime,
    required int durationSec,
    required int prescribed,
    required int completed,
    required int correct,
    required double adherence,
    required double avgAngle,
    required double avgEmg,
    required double peakEmg,
    required int hr,
    required int spo2,
    double temp = 27.4,
    double hum = 61.0,
    String? aiSummary,
  }) {
    final reps = <RepetitionData>[];
    final incorrect = completed - correct;
    for (int i = 1; i <= completed; i++) {
      final isShallow = i > (completed - incorrect);
      reps.add(RepetitionData(
        repNumber: i,
        peakAngle: isShallow ? (avgAngle - 40) : (avgAngle + (i % 5)),
        duration: 2.3,
        verdict: isShallow ? RepVerdict.tooShallow : RepVerdict.correct,
        emgActivation: avgEmg + (i % 8),
        timestamp: startTime.add(Duration(seconds: i * 8)),
      ));
    }

    return SessionRecord(
      id: id,
      patientId: AppConstants.defaultPatientId,
      exercise: ExercisePresets.kneeExtensionId,
      exerciseName: 'Seated Knee Extension',
      startTime: startTime,
      durationSeconds: durationSec,
      prescribedReps: prescribed,
      completedReps: completed,
      correctReps: correct,
      incorrectReps: incorrect,
      adherence: adherence,
      averageAngle: avgAngle,
      maxHR: hr,
      minSpO2: spo2,
      temperature: temp,
      humidity: hum,
      averageEmg: avgEmg,
      peakEmg: peakEmg,
      repetitions: reps,
      isSynced: true,
      aiSummary: aiSummary,
    );
  }

  // --- Patients ---
  Future<void> savePatient(Patient patient) async {
    final list = getPatients();
    final index = list.indexWhere((p) => p.id == patient.id);
    if (index >= 0) {
      list[index] = patient;
    } else {
      list.add(patient);
    }
    final raw = list.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_patientsKey, raw);
  }

  List<Patient> getPatients() {
    final raw = _prefs.getStringList(_patientsKey) ?? [];
    return raw.map((str) => Patient.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
  }

  Patient? getPatientById(String id) {
    final list = getPatients();
    return list.cast<Patient?>().firstWhere((p) => p?.id == id, orElse: () => null);
  }

  // --- Prescriptions ---
  Future<void> savePrescription(Prescription rx) async {
    final list = getPrescriptions();
    final index = list.indexWhere((p) => p.id == rx.id);
    if (index >= 0) {
      list[index] = rx;
    } else {
      list.add(rx);
    }
    final raw = list.map((p) => jsonEncode(p.toJson())).toList();
    await _prefs.setStringList(_prescriptionsKey, raw);
  }

  List<Prescription> getPrescriptions() {
    final raw = _prefs.getStringList(_prescriptionsKey) ?? [];
    return raw.map((str) => Prescription.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
  }

  Prescription? getPrescriptionForPatient(String patientId, {String? exerciseId}) {
    final list = getPrescriptions().where((rx) => rx.patientId == patientId).toList();
    if (list.isEmpty) return ExercisePresets.kneeExtensionPrescription;
    if (exerciseId != null) {
      return list.firstWhere((rx) => rx.exerciseId == exerciseId, orElse: () => list.first);
    }
    return list.first;
  }

  // --- Sessions ---
  Future<void> saveSession(SessionRecord session) async {
    final list = getSessions();
    final index = list.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      list[index] = session;
    } else {
      list.insert(0, session); // Newest first
    }
    final raw = list.map((s) => jsonEncode(s.toJson())).toList();
    await _prefs.setStringList(_sessionsKey, raw);

    if (!session.isSynced) {
      await addToSyncQueue(session.id);
    }
  }

  List<SessionRecord> getSessions({String? patientId}) {
    final raw = _prefs.getStringList(_sessionsKey) ?? [];
    var list = raw.map((str) => SessionRecord.fromJson(jsonDecode(str) as Map<String, dynamic>)).toList();
    if (patientId != null) {
      list = list.where((s) => s.patientId == patientId).toList();
    }
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  // --- Sync Queue ---
  Future<void> addToSyncQueue(String sessionId) async {
    final queue = getSyncQueue();
    if (!queue.contains(sessionId)) {
      queue.add(sessionId);
      await _prefs.setStringList(_syncQueueKey, queue);
    }
  }

  List<String> getSyncQueue() {
    return _prefs.getStringList(_syncQueueKey) ?? [];
  }

  Future<void> clearSyncItem(String sessionId) async {
    final queue = getSyncQueue();
    queue.remove(sessionId);
    await _prefs.setStringList(_syncQueueKey, queue);

    // Mark session as synced in storage
    final list = getSessions();
    final index = list.indexWhere((s) => s.id == sessionId);
    if (index >= 0) {
      list[index] = list[index].copyWith(isSynced: true);
      final raw = list.map((s) => jsonEncode(s.toJson())).toList();
      await _prefs.setStringList(_sessionsKey, raw);
    }
  }
}
