import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/theme/app_theme.dart';
import 'package:rehabrep/data/firebase/firebase_auth_service.dart';
import 'package:rehabrep/data/local/session_local_db.dart';
import 'package:rehabrep/features/auth/auth_provider.dart';
import 'package:rehabrep/features/progress/user_progress_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('UserProgressScreen renders rehabilitation metrics and adherence', (WidgetTester tester) async {
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
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const UserProgressScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Progress screen titles & metrics
    expect(find.text('Your Progress'), findsOneWidget);
    expect(find.text('Weekly Adherence'), findsWidgets);
    expect(find.text('Correct Reps'), findsOneWidget);
    expect(find.text('Sessions Done'), findsOneWidget);
    expect(find.text('Average ROM'), findsOneWidget);
    expect(find.text('Recent Completed Sessions'), findsOneWidget);
  });
}
