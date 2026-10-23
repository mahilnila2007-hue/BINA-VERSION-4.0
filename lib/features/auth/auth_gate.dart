import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/color_palette.dart';
import '../../widgets/app_logo.dart';
import 'auth_provider.dart';
import 'sign_in_screen.dart';

/// Central Authentication Gate for ReHabRep.
/// Decision hierarchy:
///   1. Check authentication state.
///   2. If authenticated -> Redirects / launches User Dashboard.
///   3. If NOT authenticated -> Displays the production Sign In screen.
class AuthGate extends ConsumerStatefulWidget {
  const AuthGate({super.key});

  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkInitialAuth();
  }

  Future<void> _checkInitialAuth() async {
    // Brief check for smooth presentation without visual flicker
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        // Authenticated user proceeds to Home Dashboard
        context.go('/home');
      } else {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    if (user != null) {
      // User is authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/home');
        }
      });
      return _buildLoadingScreen('Loading your recovery dashboard...');
    }

    if (_isChecking) {
      return _buildLoadingScreen('Checking authorization...');
    }

    // Unauthenticated user -> Sign In Screen
    return const SignInScreen();
  }

  Widget _buildLoadingScreen(String status) {
    return Scaffold(
      backgroundColor: AppPalette.warmWhite,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppLogo(
                size: 88,
                isCircle: true,
                showBorder: true,
              ),
              const SizedBox(height: 24),
              Text(
                AppConstants.appName.toUpperCase(),
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: AppPalette.charcoalDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'AI-Powered Home Rehabilitation',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppPalette.charcoalMuted,
                ),
              ),
              const SizedBox(height: 36),
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(AppPalette.orange),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                status,
                style: TextStyle(
                  fontSize: 13,
                  color: AppPalette.charcoalMuted.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
