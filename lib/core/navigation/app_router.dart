import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/session_record.dart';
import '../../features/auth/auth_gate.dart';
import '../../features/auth/sign_in_screen.dart';
import '../../features/auth/sign_up_screen.dart';
import '../../features/chatbot/rehab_ai_screen.dart';
import '../../features/exercises/exercise_detail_screen.dart';
import '../../features/exercises/exercise_list_screen.dart';
import '../../features/patient/patient_dashboard_screen.dart';
import '../../features/patient/session_setup_screen.dart';
import '../../features/patient/session_summary_screen.dart';
import '../../features/profile/user_profile_screen.dart';
import '../../features/progress/user_progress_screen.dart';
import '../../features/session/exercise_session_screen.dart';
import 'app_shell.dart';

/// Creates a fresh GoRouter instance for ReHabRep.
GoRouter createAppRouter({
  String initialLocation = '/',
  GlobalKey<NavigatorState>? navigatorKey,
}) {
  final rootNavigatorKey =
      navigatorKey ?? GlobalKey<NavigatorState>(debugLabel: 'root');

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    routes: [
      // Authentication Gate (First decision point after launch)
      GoRoute(
        path: '/',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AuthGate(),
      ),

      // Authentication Routes
      GoRoute(
        path: '/sign-in',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignInScreen(),
      ),
      GoRoute(
        path: '/sign-up',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SignUpScreen(),
      ),

      // Persistent Navigation Shell (5 Primary User Tabs)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Tab 0: Home Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const PatientDashboardScreen(),
              ),
            ],
          ),

          // Tab 1: Exercises & Video Tutorials
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/exercises',
                builder: (context, state) => const ExerciseListScreen(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) {
                      final exerciseId =
                          state.pathParameters['id'] ?? 'knee_extension';
                      return ExerciseDetailScreen(exerciseId: exerciseId);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Tab 2: Recovery Progress
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                builder: (context, state) => const UserProgressScreen(),
              ),
            ],
          ),

          // Tab 3: ReHab AI Coach
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai-coach',
                builder: (context, state) => const ReHabAiScreen(),
              ),
            ],
          ),

          // Tab 4: Profile & Preferences
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => const UserProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-Screen Live Exercise Experience (Hero Camera + YOLO Pose)
      GoRoute(
        path: '/session/setup',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const SessionSetupScreen(),
      ),
      GoRoute(
        path: '/session/live',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final isReplay = state.uri.queryParameters['replay'] == 'true';
          return ExerciseSessionScreen(isReplayMode: isReplay);
        },
      ),
      GoRoute(
        path: '/session/summary',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final session = state.extra as SessionRecord?;
          return SessionSummaryScreen(session: session);
        },
      ),

      // Legacy Route Aliases
      GoRoute(
        path: '/patient',
        redirect: (context, state) => '/home',
        routes: [
          GoRoute(
            path: 'setup',
            redirect: (context, state) => '/session/setup',
          ),
          GoRoute(
            path: 'session',
            redirect: (context, state) => '/session/live',
          ),
          GoRoute(
            path: 'summary',
            redirect: (context, state) => '/session/summary',
          ),
        ],
      ),
    ],
  );
}

/// Global shared instance for application runtime.
final GoRouter appRouter = createAppRouter();
