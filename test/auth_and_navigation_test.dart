import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/constants/app_constants.dart';
import 'package:rehabrep/core/theme/app_theme.dart';
import 'package:rehabrep/data/firebase/firebase_auth_service.dart';
import 'package:rehabrep/data/local/session_local_db.dart';
import 'package:rehabrep/features/auth/auth_provider.dart';
import 'package:rehabrep/features/auth/sign_in_screen.dart';
import 'package:rehabrep/features/auth/sign_up_screen.dart';
import 'package:rehabrep/features/exercises/exercise_detail_screen.dart';
import 'package:rehabrep/features/exercises/exercise_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SessionLocalDb localDb;
  late FirebaseAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localDb = await SessionLocalDb.init();
    final prefs = await SharedPreferences.getInstance();
    authService = FirebaseAuthService(prefs, localDb);
  });

  testWidgets('SignInScreen renders HealthTech branding, inputs, and actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(localDb),
          firebaseAuthServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SignInScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Remember me'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.textContaining('Sign Up'), findsOneWidget);
  });

  testWidgets('SignUpScreen renders patient registration fields and terms', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(localDb),
          firebaseAuthServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SignUpScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
    expect(find.textContaining('Terms and Privacy Policy'), findsOneWidget);
    expect(find.text('CREATE ACCOUNT'), findsOneWidget);
    expect(find.textContaining('Sign In'), findsOneWidget);
  });

  testWidgets('ExerciseListScreen renders prescribed exercises and guides', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(localDb),
          firebaseAuthServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ExerciseListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Rehab Exercises'), findsOneWidget);
    expect(find.text('Finger Exercise'), findsOneWidget);
    expect(find.text('Leg Exercise'), findsOneWidget);
    expect(find.text('Guide & Video'), findsWidgets);
    expect(find.text('Start Exercise'), findsWidgets);
  });

  testWidgets('ExerciseDetailScreen renders instructional video and START LIVE EXERCISE button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(localDb),
          firebaseAuthServiceProvider.overrideWithValue(authService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ExerciseDetailScreen(exerciseId: 'knee_extension'),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Knee Exercise'), findsWidgets);
    expect(find.text('Open Video'), findsOneWidget);
    expect(find.text('How to perform'), findsOneWidget);
    expect(find.text('Camera Placement Guidance'), findsOneWidget);
    expect(find.text('START LIVE EXERCISE'), findsOneWidget);
  });
}
