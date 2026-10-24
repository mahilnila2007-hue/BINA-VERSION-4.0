import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rehabrep/core/constants/exercise_presets.dart';
import 'package:rehabrep/core/theme/app_theme.dart';
import 'package:rehabrep/core/utils/video_launcher_helper.dart';
import 'package:rehabrep/data/firebase/firebase_auth_service.dart';
import 'package:rehabrep/data/local/session_local_db.dart';
import 'package:rehabrep/features/auth/auth_provider.dart';
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

  group('Exercise -> YouTube URL Mapping Tests', () {
    test('All 6 exercises have correct YouTube video IDs and full URLs', () {
      final expectedMappings = {
        ExercisePresets.fingerExerciseId: {
          'name': 'Finger Exercise',
          'videoId': 'CWW0n16QCcA',
          'url': 'https://www.youtube.com/watch?v=CWW0n16QCcA',
        },
        ExercisePresets.legExerciseId: {
          'name': 'Leg Exercise',
          'videoId': '1kVUlwHzGso',
          'url': 'https://www.youtube.com/watch?v=1kVUlwHzGso',
        },
        ExercisePresets.handExerciseId: {
          'name': 'Hand Exercise',
          'videoId': 'XIpa7NtedwM',
          'url': 'https://www.youtube.com/watch?v=XIpa7NtedwM',
        },
        ExercisePresets.hipExerciseId: {
          'name': 'Hip Exercise',
          'videoId': 'pCsuDA5W_9g',
          'url': 'https://www.youtube.com/watch?v=pCsuDA5W_9g',
        },
        ExercisePresets.elbowExerciseId: {
          'name': 'Elbow Exercise',
          'videoId': '3RhAXHRvrKI',
          'url': 'https://www.youtube.com/watch?v=3RhAXHRvrKI',
        },
        ExercisePresets.kneeExerciseId: {
          'name': 'Knee Exercise',
          'videoId': 'hw_yl3qmO88',
          'url': 'https://www.youtube.com/watch?v=hw_yl3qmO88',
        },
      };

      expect(ExercisePresets.allPresets.length, equals(6));

      for (final entry in expectedMappings.entries) {
        final exercise = ExercisePresets.getById(entry.key);
        expect(exercise.exerciseName, equals(entry.value['name']));
        expect(exercise.trainingVideoUrl, equals(entry.value['url']));
        expect(
          VideoLauncherHelper.extractVideoId(exercise.trainingVideoUrl),
          equals(entry.value['videoId']),
        );
      }
    });

    test('VideoLauncherHelper correctly parses various YouTube URL formats', () {
      expect(
        VideoLauncherHelper.extractVideoId('CWW0n16QCcA'),
        equals('CWW0n16QCcA'),
      );
      expect(
        VideoLauncherHelper.extractVideoId('https://www.youtube.com/watch?v=1kVUlwHzGso'),
        equals('1kVUlwHzGso'),
      );
      expect(
        VideoLauncherHelper.extractVideoId('https://youtu.be/XIpa7NtedwM'),
        equals('XIpa7NtedwM'),
      );
      expect(
        VideoLauncherHelper.extractVideoId('https://m.youtube.com/watch?v=pCsuDA5W_9g&t=10s'),
        equals('pCsuDA5W_9g'),
      );
      expect(
        VideoLauncherHelper.extractVideoId('https://www.youtube.com/embed/3RhAXHRvrKI'),
        equals('3RhAXHRvrKI'),
      );
      expect(
        VideoLauncherHelper.getFullWebUrl('hw_yl3qmO88'),
        equals('https://www.youtube.com/watch?v=hw_yl3qmO88'),
      );
    });
  });

  group('Individual Exercise Open Video Button Tests', () {
    Future<void> pumpExerciseDetail(WidgetTester tester, String exerciseId) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionLocalDbProvider.overrideWithValue(localDb),
            firebaseAuthServiceProvider.overrideWithValue(authService),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: ExerciseDetailScreen(exerciseId: exerciseId),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('1. Finger Exercise -> Open Video button renders with correct video ID CWW0n16QCcA', (tester) async {
      await pumpExerciseDetail(tester, ExercisePresets.fingerExerciseId);

      expect(find.text('Finger Exercise'), findsWidgets);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Open Video');
      expect(buttonFinder, findsOneWidget);

      final rx = ExercisePresets.getById(ExercisePresets.fingerExerciseId);
      expect(rx.trainingVideoUrl, contains('CWW0n16QCcA'));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('2. Leg Exercise -> Open Video button renders with correct video ID 1kVUlwHzGso', (tester) async {
      await pumpExerciseDetail(tester, ExercisePresets.legExerciseId);

      expect(find.text('Leg Exercise'), findsWidgets);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Open Video');
      expect(buttonFinder, findsOneWidget);

      final rx = ExercisePresets.getById(ExercisePresets.legExerciseId);
      expect(rx.trainingVideoUrl, contains('1kVUlwHzGso'));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('3. Hand Exercise -> Open Video button renders with correct video ID XIpa7NtedwM', (tester) async {
      await pumpExerciseDetail(tester, ExercisePresets.handExerciseId);

      expect(find.text('Hand Exercise'), findsWidgets);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Open Video');
      expect(buttonFinder, findsOneWidget);

      final rx = ExercisePresets.getById(ExercisePresets.handExerciseId);
      expect(rx.trainingVideoUrl, contains('XIpa7NtedwM'));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('4. Hip Exercise -> Open Video button renders with correct video ID pCsuDA5W_9g', (tester) async {
      await pumpExerciseDetail(tester, ExercisePresets.hipExerciseId);

      expect(find.text('Hip Exercise'), findsWidgets);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Open Video');
      expect(buttonFinder, findsOneWidget);

      final rx = ExercisePresets.getById(ExercisePresets.hipExerciseId);
      expect(rx.trainingVideoUrl, contains('pCsuDA5W_9g'));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('5. Elbow Exercise -> Open Video button renders with correct video ID 3RhAXHRvrKI', (tester) async {
      await pumpExerciseDetail(tester, ExercisePresets.elbowExerciseId);

      expect(find.text('Elbow Exercise'), findsWidgets);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Open Video');
      expect(buttonFinder, findsOneWidget);

      final rx = ExercisePresets.getById(ExercisePresets.elbowExerciseId);
      expect(rx.trainingVideoUrl, contains('3RhAXHRvrKI'));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('6. Knee Exercise -> Open Video button renders with correct video ID hw_yl3qmO88', (tester) async {
      await pumpExerciseDetail(tester, ExercisePresets.kneeExerciseId);

      expect(find.text('Knee Exercise'), findsWidgets);
      final buttonFinder = find.widgetWithText(ElevatedButton, 'Open Video');
      expect(buttonFinder, findsOneWidget);

      final rx = ExercisePresets.getById(ExercisePresets.kneeExerciseId);
      expect(rx.trainingVideoUrl, contains('hw_yl3qmO88'));

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();
    });

    testWidgets('ExerciseListScreen renders exercises with Guide & Video actions', (tester) async {
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

      expect(find.text('Finger Exercise'), findsOneWidget);
      expect(find.text('Leg Exercise'), findsOneWidget);
      expect(find.text('Guide & Video'), findsWidgets);
    });
  });
}
