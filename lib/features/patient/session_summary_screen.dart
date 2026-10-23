import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/typography.dart';
import '../../domain/models/session_record.dart';
import '../../widgets/responsive_screen_frame.dart';
import '../auth/auth_provider.dart';

/// Screen displayed immediately after exercise completion.
/// Clear celebration, high contrast metrics, and one large [FINISH] button.
class SessionSummaryScreen extends ConsumerWidget {
  final SessionRecord? session;

  const SessionSummaryScreen({super.key, this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final correctReps = session?.correctReps ?? 9;
    final totalReps = session?.completedReps ?? 10;
    final accuracy = session?.adherence ?? 90.0;
    final durationText = session?.formattedDuration ?? '02:45';

    return ResponsiveScreenFrame(
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Success Celebration Icon
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: AppColors.successContainer,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.success.withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppColors.success,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'SESSION COMPLETE',
                textAlign: TextAlign.center,
                style: AppTypography.headingLarge(),
              ),
              const SizedBox(height: 8),
              Text(
                'Great rehabilitation progress!',
                textAlign: TextAlign.center,
                style: AppTypography.patientBodyMedium(),
              ),
              const SizedBox(height: 28),

              // Metric Card 1: Good Repetitions
              _buildMetricCard(
                title: 'Good repetitions',
                value: '$correctReps / $totalReps',
                icon: Icons.done_all_rounded,
                accentColor: AppColors.success,
              ),

              const SizedBox(height: 16),

              // Metric Card 2: Form Accuracy / Adherence
              _buildMetricCard(
                title: 'Form accuracy',
                value: '${accuracy.toStringAsFixed(0)}%',
                icon: Icons.insights_rounded,
                accentColor: AppColors.primary,
              ),

              const SizedBox(height: 16),

              // Metric Card 3: Session Duration
              _buildMetricCard(
                title: 'Session duration',
                value: durationText,
                icon: Icons.timer_outlined,
                accentColor: AppColors.secondary,
              ),

              const SizedBox(height: 28),

              // Sync Status Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isOnline ? AppColors.successContainer : AppColors.secondaryContainer,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isOnline ? AppColors.success : AppColors.secondary,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.offline_pin_rounded,
                      color: isOnline ? AppColors.onSuccess : AppColors.onSecondaryContainer,
                      size: 26,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '✓ Session saved',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: isOnline ? AppColors.onSuccess : AppColors.onSecondaryContainer,
                            ),
                          ),
                          Text(
                            isOnline
                                ? 'Synced to Dr. Priya\'s dashboard'
                                : 'Saved locally offline. Will sync when connected.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isOnline ? AppColors.onSuccess : AppColors.onSecondaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 36),

              // ONE LARGE FINISH BUTTON (78dp high)
              Semantics(
                button: true,
                label: 'Finish and return to home',
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/home');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(78),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                  child: const Text('FINISH'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.cardBorderLight, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 28, color: accentColor),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: AppTypography.patientBodyMedium().copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: AppTypography.headingMedium().copyWith(
              fontSize: 26,
              color: accentColor,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
