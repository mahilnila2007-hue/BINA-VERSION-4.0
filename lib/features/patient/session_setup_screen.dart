import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/accessibility/accessibility_helper.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/typography.dart';
import '../../domain/services/tts_service.dart';
import '../../widgets/responsive_screen_frame.dart';
import '../auth/auth_provider.dart';

/// Camera Readiness Check Screen (Section 7).
/// Verifies person detection, full body visibility, and camera position
/// before allowing exercise start with [ I'M READY ].
class SessionSetupScreen extends ConsumerStatefulWidget {
  const SessionSetupScreen({super.key});

  @override
  ConsumerState<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends ConsumerState<SessionSetupScreen> {
  bool _personDetected = false;
  bool _bodyVisible = false;
  bool _cameraPositionGood = false;
  bool _isAllReady = false;

  Timer? _t1;
  Timer? _t2;
  Timer? _t3;

  @override
  void initState() {
    super.initState();
    _startReadinessVerification();
  }

  void _startReadinessVerification() {
    TtsService().speak('Move your full body inside the frame.');

    // Simulated staggered camera verification pipeline
    _t1 = Timer(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _personDetected = true);
    });

    _t2 = Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      setState(() => _bodyVisible = true);
    });

    _t3 = Timer(const Duration(milliseconds: 2100), () {
      if (!mounted) return;
      setState(() {
        _cameraPositionGood = true;
        _isAllReady = true;
      });
      TtsService().speak("You're ready. Tap I'm ready to begin.");
      AccessibilityHelper.announce(context, "You're ready. Tap I'm ready to begin.");
    });
  }

  @override
  void dispose() {
    _t1?.cancel();
    _t2?.cancel();
    _t3?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rx = ref.watch(currentPrescriptionProvider);

    return ResponsiveScreenFrame(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Camera Check',
          style: AppTypography.headingMedium().copyWith(fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Section 7: Title
              Text(
                'GET READY',
                style: AppTypography.headingLarge().copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Text(
                'Move your full body inside the frame.',
                style: AppTypography.patientBodyLarge(),
              ),
              const SizedBox(height: 20),

              // Camera Viewport Preview Card
              Container(
                height: 280,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Silhouette Guide
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.accessibility_new_rounded,
                          size: 110,
                          color: _isAllReady
                              ? AppColors.success.withValues(alpha: 0.85)
                              : Colors.white.withValues(alpha: 0.35),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isAllReady
                                ? AppColors.success.withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isAllReady ? AppColors.success : Colors.white30,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _isAllReady ? 'YOLO POSE ACTIVE' : 'ALIGN YOUR BODY',
                            style: TextStyle(
                              color: _isAllReady ? AppColors.success : Colors.white70,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Target Joint Tag
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          rx?.targetJointName ?? 'Knee (Hip → Knee → Ankle)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Section 7: Verification Checklist
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.cardBorderLight, width: 1.4),
                ),
                child: Column(
                  children: [
                    _buildCheckItem(
                      label: 'Person detected',
                      isVerified: _personDetected,
                    ),
                    const Divider(height: 22, color: AppColors.cardBorderLight),
                    _buildCheckItem(
                      label: 'Body visible',
                      isVerified: _bodyVisible,
                    ),
                    const Divider(height: 22, color: AppColors.cardBorderLight),
                    _buildCheckItem(
                      label: 'Good camera position',
                      isVerified: _cameraPositionGood,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // Section 7 Dominant Action: [ I'M READY ]
              Semantics(
                button: true,
                label: "I'm ready to start exercise",
                child: ElevatedButton.icon(
                  onPressed: _isAllReady
                      ? () {
                          context.go('/session/live');
                        }
                      : null,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 32),
                  label: Text(_isAllReady ? "I'M READY" : 'CHECKING POSITION...'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(78),
                    elevation: 5,
                    shadowColor: AppColors.primary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildCheckItem({
    required String label,
    required bool isVerified,
  }) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isVerified ? AppColors.successContainer : AppColors.surfaceVariantLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isVerified ? AppColors.success : AppColors.cardBorderLight,
              width: 1.5,
            ),
          ),
          child: Icon(
            isVerified ? Icons.check_rounded : Icons.hourglass_top_rounded,
            size: 20,
            color: isVerified ? AppColors.success : AppColors.textTertiaryLight,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            label,
            style: AppTypography.patientBodyLarge().copyWith(
              fontSize: 19,
              color: isVerified ? AppColors.textPrimaryLight : AppColors.textSecondaryLight,
              fontWeight: isVerified ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
        if (isVerified)
          Text(
            'Ready',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
      ],
    );
  }
}
