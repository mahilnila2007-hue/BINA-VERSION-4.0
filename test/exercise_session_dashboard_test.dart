import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/data/firebase/firebase_auth_service.dart';
import 'package:rehabrep/data/local/session_local_db.dart';
import 'package:rehabrep/features/auth/auth_provider.dart';
import 'package:rehabrep/features/session/exercise_session_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SessionLocalDb localDb;
  late FirebaseAuthService authService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    localDb = await SessionLocalDb.init();
    final prefs = await SharedPreferences.getInstance();
    authService = FirebaseAuthService(prefs, localDb);
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        sessionLocalDbProvider.overrideWithValue(localDb),
        firebaseAuthServiceProvider.overrideWithValue(authService),
      ],
      child: const MaterialApp(
        home: ExerciseSessionScreen(),
      ),
    );
  }

  group('ExerciseSessionScreen Live Dashboard Tests', () {
    testWidgets('1. Dashboard displays realistic physiological data immediately on startup in DEMO MODE', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Verify LIVE DASHBOARD title and DEMO MODE indicator
      expect(find.text('LIVE DASHBOARD'), findsOneWidget);
      expect(find.text('DEMO MODE'), findsOneWidget);

      // Verify HR chip displays realistic immediate value (72 BPM), NOT '--'
      expect(find.text('72 BPM'), findsOneWidget);
      expect(find.text('-- BPM'), findsNothing);

      // Verify SpO2 chip displays realistic immediate value (98 %), NOT '--'
      expect(find.text('98 %'), findsOneWidget);
      expect(find.text('-- %'), findsNothing);

      // Verify EMG chip displays realistic immediate value (42 %), NOT '--'
      expect(find.text('42 %'), findsOneWidget);

      // Verify EMG Graph header does NOT show 0%
      expect(find.text('EMG Graph'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);

      // Verify REP, ANGLE, and FORM are displayed
      expect(find.textContaining('REP 00/'), findsOneWidget);
      expect(find.textContaining('ANGLE'), findsWidgets);
      expect(find.textContaining('FORM'), findsOneWidget);

      // Verify Action buttons [PAUSE] and [STOP]
      expect(find.text('PAUSE'), findsOneWidget);
      expect(find.text('STOP'), findsOneWidget);
    });

    testWidgets('2. Tapping mode toggle switches between DEMO MODE and REAL-TIME mode', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      // Starts in DEMO MODE
      expect(find.text('DEMO MODE'), findsOneWidget);
      expect(find.text('72 BPM'), findsOneWidget);

      // Tap Mode toggle
      await tester.tap(find.text('DEMO MODE'));
      await tester.pump();

      // Switches to REAL-TIME mode
      expect(find.text('REAL-TIME'), findsOneWidget);
      // Disconnected hardware shows '--'
      expect(find.text('-- BPM'), findsOneWidget);
      expect(find.text('-- %'), findsNWidgets(2)); // SpO2 and EMG

      // Tap Mode toggle again to return to DEMO MODE
      await tester.tap(find.text('REAL-TIME'));
      await tester.pump();

      // Returns to DEMO MODE with immediate valid physiological values
      expect(find.text('DEMO MODE'), findsOneWidget);
      expect(find.text('-- BPM'), findsNothing);
    });

    testWidgets('3. Continuous timer updates biosignals smoothly in DEMO MODE', (tester) async {
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.text('72 BPM'), findsOneWidget);

      // Advance clock by 350ms (two 150ms simulation ticks)
      await tester.pump(const Duration(milliseconds: 350));

      // In demo mode, values update continuously and never show '--'
      expect(find.text('-- BPM'), findsNothing);
      expect(find.text('-- %'), findsNothing);
    });
  });
}
