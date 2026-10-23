import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/constants/app_constants.dart';
import 'package:rehabrep/core/navigation/app_router.dart';
import 'package:rehabrep/data/firebase/firebase_auth_service.dart';
import 'package:rehabrep/data/local/session_local_db.dart';
import 'package:rehabrep/domain/models/user_profile.dart';
import 'package:rehabrep/features/auth/auth_provider.dart';
import 'package:rehabrep/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ReHabRep Comprehensive Authentication Flow Tests (Section 12)', () {
    late SessionLocalDb localDb;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      localDb = await SessionLocalDb.init();
    });

    void configureViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    }

    testWidgets('Test 1: Fresh app launch shows AuthGate and settles on Sign In Screen', (tester) async {
      configureViewport(tester);
      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseAuthService(prefs, localDb);
      final router = createAppRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: ReHabRepApp(router: router),
        ),
      );

      // AuthGate initial check (300ms)
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verified: Sign In Screen is displayed with all branding and inputs
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Your AI-powered home rehabilitation coach'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(find.textContaining('Sign Up'), findsOneWidget);
    });

    testWidgets('Test 2: Tapping "Sign Up" navigates to the Sign Up screen', (tester) async {
      configureViewport(tester);
      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseAuthService(prefs, localDb);
      final router = createAppRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: ReHabRepApp(router: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Tap Sign Up link
      await tester.tap(find.textContaining('Sign Up'));
      await tester.pumpAndSettle();

      // Verified: Sign Up screen is displayed
      expect(find.text('Create your account'), findsOneWidget);
      expect(find.text('Full name'), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm password'), findsOneWidget);
      expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    });

    testWidgets('Test 3: Creating an account creates Firebase profile and enters Dashboard', (tester) async {
      configureViewport(tester);
      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseAuthService(prefs, localDb);
      final router = createAppRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: ReHabRepApp(router: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Navigate to Sign Up
      await tester.tap(find.textContaining('Sign Up'));
      await tester.pumpAndSettle();

      // Fill in registration form
      await tester.enterText(find.widgetWithText(TextFormField, 'Enter your full name'), 'John Doe');
      await tester.enterText(find.widgetWithText(TextFormField, 'Enter your email address'), 'john.doe@example.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Create a password (min. 6 characters)'), 'SecurePass123!');
      await tester.enterText(find.widgetWithText(TextFormField, 'Re-enter your password'), 'SecurePass123!');

      // Check Terms checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      // Tap CREATE ACCOUNT
      await tester.tap(find.text('CREATE ACCOUNT'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Verified: Enters Dashboard
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text("Today's Exercise"), findsOneWidget);
      expect(find.text('START EXERCISE'), findsOneWidget);

      // Verified: User profile in Firebase service
      expect(authService.currentUser?.name, 'John Doe');
      expect(authService.currentUser?.email, 'john.doe@example.com');
      expect(authService.isAuthenticated, isTrue);
    });

    testWidgets('Test 4: Signing in with existing account enters Dashboard', (tester) async {
      configureViewport(tester);
      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseAuthService(prefs, localDb);
      final router = createAppRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: ReHabRepApp(router: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Tap Demo fill chip
      await tester.tap(find.text('Fill Demo: arun@rehabrep.com'));
      await tester.pumpAndSettle();

      // Tap SIGN IN
      await tester.tap(find.text('SIGN IN'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      // Verified: Arrives at user dashboard
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text("Today's Exercise"), findsOneWidget);
      expect(authService.isAuthenticated, isTrue);
      expect(authService.currentUser?.email, 'arun@rehabrep.com');
    });

    testWidgets('Test 5: App restart with persisted session loads Dashboard without login screen', (tester) async {
      configureViewport(tester);
      final existingUser = UserProfile(
        id: 'patient_arun_001',
        name: 'Arun',
        email: 'arun@rehabrep.com',
        age: 68,
        createdAt: DateTime.now(),
      );

      // Simulate persistent login in SharedPreferences
      SharedPreferences.setMockInitialValues({
        'rehabrep_auth_current_user': jsonEncode(existingUser.toJson()),
      });

      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseAuthService(prefs, localDb);
      final router = createAppRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: ReHabRepApp(router: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verified: User Dashboard loaded immediately
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Exercises'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('Test 6: Signing out clears session and redirects to Sign In screen', (tester) async {
      configureViewport(tester);
      final existingUser = UserProfile(
        id: 'patient_arun_001',
        name: 'Arun',
        email: 'arun@rehabrep.com',
        age: 68,
        createdAt: DateTime.now(),
      );

      SharedPreferences.setMockInitialValues({
        'rehabrep_auth_current_user': jsonEncode(existingUser.toJson()),
      });

      final prefs = await SharedPreferences.getInstance();
      final authService = FirebaseAuthService(prefs, localDb);
      final router = createAppRouter();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: ReHabRepApp(router: router),
        ),
      );

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Navigate to Profile Tab
      router.go('/profile');
      await tester.pumpAndSettle();

      expect(find.text('Profile & Settings'), findsOneWidget);

      // Scroll to ensure SIGN OUT is visible and tap it
      await tester.scrollUntilVisible(find.text('SIGN OUT'), 200);
      await tester.tap(find.text('SIGN OUT'));
      await tester.pumpAndSettle();

      // Confirm Sign Out dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign Out'));
      await tester.pumpAndSettle();

      // Verified: Returns to Sign In Screen
      expect(find.text(AppConstants.appName), findsOneWidget);
      expect(find.text('Email address'), findsOneWidget);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
