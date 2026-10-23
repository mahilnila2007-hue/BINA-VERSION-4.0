import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/constants/app_constants.dart';
import 'package:rehabrep/data/firebase/firebase_auth_service.dart';
import 'package:rehabrep/data/local/session_local_db.dart';
import 'package:rehabrep/domain/models/user_profile.dart';
import 'package:rehabrep/features/auth/auth_provider.dart';
import 'package:rehabrep/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Fresh launch without active session starts at Sign In screen via AuthGate', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final localDb = await SessionLocalDb.init();
    final prefs = await SharedPreferences.getInstance();
    final authService = FirebaseAuthService(prefs, localDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(localDb),
          firebaseAuthServiceProvider.overrideWithValue(authService),
        ],
        child: const ReHabRepApp(),
      ),
    );

    // Initial check in AuthGate has a 300ms delay
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verify Sign In Screen is presented
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.textContaining('Sign Up'), findsOneWidget);
  });

  testWidgets('Authenticated user launch restores session and renders Dashboard', (WidgetTester tester) async {
    final defaultUser = UserProfile(
      id: AppConstants.defaultPatientId,
      name: 'Arun',
      email: 'arun@rehabrep.com',
      age: 68,
      createdAt: DateTime.now(),
    );

    SharedPreferences.setMockInitialValues({
      'rehabrep_auth_current_user': jsonEncode(defaultUser.toJson()),
    });

    final localDb = await SessionLocalDb.init();
    final prefs = await SharedPreferences.getInstance();
    final authService = FirebaseAuthService(prefs, localDb);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(localDb),
          firebaseAuthServiceProvider.overrideWithValue(authService),
        ],
        child: const ReHabRepApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Verify User Dashboard elements
    expect(find.text("Today's Progress"), findsOneWidget);
    expect(find.text("Today's Exercise"), findsOneWidget);
    expect(find.text('START EXERCISE'), findsOneWidget);

    // Verify Persistent Bottom Navigation Tabs
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Exercises'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);
    expect(find.text('AI Coach'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
  });
}
