import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/navigation/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/firebase/firebase_auth_service.dart';
import 'data/local/session_local_db.dart';
import 'domain/services/tts_service.dart';
import 'features/auth/auth_provider.dart';

import 'dart:async';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('ReHabRep Uncaught Flutter Error: ${details.exception}');
    };

    // Initialize SharedPreferences with safety
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('SharedPreferences error: $e');
      prefs = await SharedPreferences.getInstance();
    }

    // Initialize Local Offline Database with seeded clinical data
    SessionLocalDb sessionLocalDb;
    try {
      sessionLocalDb = await SessionLocalDb.init();
    } catch (e) {
      debugPrint('SessionLocalDb fallback init: $e');
      sessionLocalDb = SessionLocalDb(prefs);
    }

    // Initialize Speech Feedback Engine safely (non-blocking)
    try {
      await TtsService().init();
    } catch (e) {
      debugPrint('TtsService init warning: $e');
    }

    // Initialize Firebase Authentication Service
    final firebaseAuthService = FirebaseAuthService(prefs, sessionLocalDb);

    runApp(
      ProviderScope(
        overrides: [
          sessionLocalDbProvider.overrideWithValue(sessionLocalDb),
          firebaseAuthServiceProvider.overrideWithValue(firebaseAuthService),
        ],
        child: const ReHabRepApp(),
      ),
    );
  }, (error, stackTrace) {
    debugPrint('ReHabRep Global Error: $error\n$stackTrace');
  });
}

class ReHabRepApp extends StatelessWidget {
  final GoRouter? router;
  const ReHabRepApp({super.key, this.router});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router ?? appRouter,
    );
  }
}
