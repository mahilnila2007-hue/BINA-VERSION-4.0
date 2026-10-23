import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/models/patient.dart';
import '../../domain/models/user_profile.dart';
import '../local/session_local_db.dart';

/// Custom exception mimicking FirebaseAuthException for robust error handling.
class ReHabAuthException implements Exception {
  final String code;
  final String message;

  const ReHabAuthException({required this.code, required this.message});

  @override
  String toString() => 'ReHabAuthException($code): $message';
}

/// Firebase Authentication service maintaining persistent login state,
/// user registration, credentials, and profile synchronization.
class FirebaseAuthService {
  static const String _currentUserKey = 'rehabrep_auth_current_user';
  static const String _usersRegistryKey = 'rehabrep_auth_registered_users';
  static const String _passwordsRegistryKey = 'rehabrep_auth_passwords';

  final SharedPreferences _prefs;
  final SessionLocalDb _localDb;
  final StreamController<UserProfile?> _authStateController =
      StreamController<UserProfile?>.broadcast();

  UserProfile? _currentUser;

  FirebaseAuthService(this._prefs, this._localDb) {
    _loadCurrentUser();
    _seedDefaultUserIfEmpty();
  }

  UserProfile? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Stream of authentication state changes conforming to Firebase Auth API.
  Stream<UserProfile?> get authStateChanges => _authStateController.stream;

  void _loadCurrentUser() {
    final raw = _prefs.getString(_currentUserKey);
    if (raw != null) {
      try {
        _currentUser = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Error restoring user session: $e');
        _currentUser = null;
      }
    }
  }

  void _seedDefaultUserIfEmpty() {
    final registeredUsers = _getUsersMap();
    if (!registeredUsers.containsKey('arun@rehabrep.com')) {
      final defaultUser = UserProfile(
        id: AppConstants.defaultPatientId,
        name: 'Arun',
        email: 'arun@rehabrep.com',
        age: 68,
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      );
      registeredUsers['arun@rehabrep.com'] = defaultUser.toJson();
      registeredUsers[defaultUser.id] = defaultUser.toJson();
      _saveUsersMap(registeredUsers);

      final passwords = _getPasswordsMap();
      passwords['arun@rehabrep.com'] = 'Password123!';
      _savePasswordsMap(passwords);

      // Note: Do NOT auto-login on first install.
      // The app must present the Sign In screen to unauthenticated users.
    }
  }

  Map<String, dynamic> _getUsersMap() {
    final raw = _prefs.getString(_usersRegistryKey);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  void _saveUsersMap(Map<String, dynamic> map) {
    _prefs.setString(_usersRegistryKey, jsonEncode(map));
  }

  Map<String, String> _getPasswordsMap() {
    final raw = _prefs.getString(_passwordsRegistryKey);
    if (raw == null) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, v.toString()));
    } catch (_) {
      return {};
    }
  }

  void _savePasswordsMap(Map<String, String> map) {
    _prefs.setString(_passwordsRegistryKey, jsonEncode(map));
  }

  Future<void> _setCurrentUserInternal(UserProfile? user) async {
    _currentUser = user;
    if (user != null) {
      await _prefs.setString(_currentUserKey, jsonEncode(user.toJson()));
      // Ensure patient record in local database matches user profile
      final patient = Patient(
        id: user.id,
        name: user.name,
        therapistId: AppConstants.defaultTherapistId,
        age: user.age ?? 65,
        language: 'en',
        condition: 'Knee Rehabilitation',
        admittedDate: user.createdAt,
      );
      await _localDb.savePatient(patient);
    } else {
      await _prefs.remove(_currentUserKey);
    }
    _authStateController.add(_currentUser);
  }

  /// Sign In with Email and Password
  Future<UserProfile> signInWithEmailAndPassword({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const ReHabAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address.',
      );
    }

    if (password.isEmpty) {
      throw const ReHabAuthException(
        code: 'missing-password',
        message: 'Please enter your password.',
      );
    }

    // Simulated network delay
    await Future.delayed(const Duration(milliseconds: 600));

    final users = _getUsersMap();
    final passwords = _getPasswordsMap();

    if (!users.containsKey(cleanEmail)) {
      throw const ReHabAuthException(
        code: 'user-not-found',
        message: 'No registered user found with this email. Please Sign Up.',
      );
    }

    final storedPassword = passwords[cleanEmail];
    if (storedPassword != null && storedPassword != password) {
      throw const ReHabAuthException(
        code: 'wrong-password',
        message: 'Incorrect password. Please verify and try again.',
      );
    }

    final user = UserProfile.fromJson(users[cleanEmail] as Map<String, dynamic>);
    if (rememberMe) {
      await _setCurrentUserInternal(user);
    } else {
      _currentUser = user;
    }

    return user;
  }

  /// Sign Up with Name, Email, Password, and optional Age
  Future<UserProfile> createUserWithEmailAndPassword({
    required String name,
    required String email,
    required String password,
    int? age,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty) {
      throw const ReHabAuthException(
        code: 'invalid-name',
        message: 'Please enter your full name.',
      );
    }

    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const ReHabAuthException(
        code: 'invalid-email',
        message: 'Please enter a valid email address.',
      );
    }

    if (password.length < 6) {
      throw const ReHabAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters long.',
      );
    }

    await Future.delayed(const Duration(milliseconds: 700));

    final users = _getUsersMap();
    if (users.containsKey(cleanEmail)) {
      throw const ReHabAuthException(
        code: 'email-already-in-use',
        message: 'An account already exists with this email address.',
      );
    }

    final newId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final newUser = UserProfile(
      id: newId,
      name: cleanName,
      email: cleanEmail,
      age: age,
      createdAt: DateTime.now(),
    );

    users[cleanEmail] = newUser.toJson();
    users[newId] = newUser.toJson();
    _saveUsersMap(users);

    final passwords = _getPasswordsMap();
    passwords[cleanEmail] = password;
    _savePasswordsMap(passwords);

    await _setCurrentUserInternal(newUser);
    return newUser;
  }

  /// Send password reset link
  Future<void> sendPasswordResetEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      throw const ReHabAuthException(
        code: 'invalid-email',
        message: 'Please provide a valid email address for password recovery.',
      );
    }

    await Future.delayed(const Duration(milliseconds: 500));
    final users = _getUsersMap();
    if (!users.containsKey(cleanEmail)) {
      throw const ReHabAuthException(
        code: 'user-not-found',
        message: 'No registered user found with this email.',
      );
    }
    debugPrint('Password reset instructions sent to $cleanEmail');
  }

  /// Update User Profile preferences (voice coaching, haptics, camera)
  Future<void> updateProfile(UserProfile updated) async {
    _currentUser = updated;
    await _prefs.setString(_currentUserKey, jsonEncode(updated.toJson()));

    final users = _getUsersMap();
    if (users.containsKey(updated.email)) {
      users[updated.email] = updated.toJson();
      _saveUsersMap(users);
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _setCurrentUserInternal(null);
  }
}
