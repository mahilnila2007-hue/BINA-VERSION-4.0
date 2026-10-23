import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/typography.dart';
import '../auth/auth_provider.dart';
import '../chatbot/rehab_ai_bottom_sheet.dart';

/// Elderly-First Patient Home Screen.
/// Clean, high-contrast, uncluttered layout with ONE dominant action: [START EXERCISE].
/// Includes ReHab AI Coach assistant (Section 22) and focused navigation (Section 21).
class PatientHomeScreen extends ConsumerStatefulWidget {
  const PatientHomeScreen({super.key});

  @override
  ConsumerState<PatientHomeScreen> createState() => _PatientHomeScreenState();
}

class _PatientHomeScreenState extends ConsumerState<PatientHomeScreen> {
  int _selectedNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    final patient = ref.watch(currentPatientProvider);
    final prescription = ref.watch(currentPrescriptionProvider);
    final sessions = ref.watch(patientSessionsProvider);
    final isOnline = ref.watch(isOnlineProvider);

    // Calculate today's adherence/progress
    final latestSession = sessions.isNotEmpty ? sessions.first : null;
    final progressPct = latestSession != null ? (latestSession.adherence / 100.0).clamp(0.0, 1.0) : 0.80;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.accessibility_new_rounded,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              AppConstants.appName,
              style: AppTypography.headingMedium().copyWith(fontSize: 22),
            ),
          ],
        ),
        actions: [
          // Switch to Therapist / Role Select
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.swap_horiz_rounded, size: 22),
            label: const Text(
              'Switch Role',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        onPressed: () => ReHabAiBottomSheet.show(context),
        icon: const Icon(Icons.auto_awesome, size: 24),
        label: const Text(
          'ReHab AI Coach',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedNavIndex,
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primaryContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights_rounded, color: AppColors.primary),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded, color: AppColors.primary),
            label: 'Exercises',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.primary),
            label: 'Settings',
          ),
        ],
        onDestinationSelected: (idx) {
          setState(() => _selectedNavIndex = idx);
          if (idx == 1) {
            // View progress breakdown
            context.go('/therapist/patient/${AppConstants.defaultPatientId}');
          } else if (idx == 2) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Prescribed Plan: 1. Knee Extension (Active)  2. Shoulder Mobility')),
            );
          } else if (idx == 3) {
            ReHabAiBottomSheet.show(context);
          }
        },
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting & Name (Section 21)
              Text(
                'Good morning,',
                style: AppTypography.patientBodyMedium().copyWith(
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                patient?.name ?? 'Arun',
                style: AppTypography.headingLarge(),
              ),
              const SizedBox(height: 16),

              // Hardware / Monitoring Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: AppColors.cardBorderLight),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Camera Monitoring Ready',
                      style: AppTypography.clinicalBody().copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      size: 20,
                      color: isOnline ? AppColors.success : AppColors.secondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline Mode',
                      style: AppTypography.clinicalCaption(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Today's Exercise Card (Section 21)
              Card(
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: const BorderSide(color: AppColors.cardBorderLight, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.directions_run_rounded,
                              size: 38,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "TODAY'S REHABILITATION",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  prescription?.exerciseName ?? 'Knee Extension',
                                  style: AppTypography.headingLarge().copyWith(fontSize: 26),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Sets & Reps Detail (>= 22sp)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariantLight,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '${prescription?.sets ?? 3} sets × ${prescription?.reps ?? 15} reps',
                          style: AppTypography.patientBodyLarge().copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Today's Progress Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Today's progress",
                            style: AppTypography.patientBodyMedium(),
                          ),
                          Text(
                            '${(progressPct * 100).toStringAsFixed(0)}%',
                            style: AppTypography.patientBodyLarge().copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: LinearProgressIndicator(
                          value: progressPct,
                          minHeight: 18,
                          backgroundColor: AppColors.cardBorderLight,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ONE DOMINANT ACTION: [ START EXERCISE ]
              Semantics(
                button: true,
                label: 'Start Today\'s Exercise: ${prescription?.exerciseName ?? "Knee Extension"}',
                child: ElevatedButton.icon(
                  onPressed: () {
                    context.go('/patient/setup');
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 36),
                  label: const Text('START EXERCISE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(78),
                    elevation: 5,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Next Exercise Card (Section 21)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.cardBorderLight),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded, color: AppColors.secondary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NEXT UP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: AppColors.secondary,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Shoulder Mobility',
                            style: AppTypography.patientBodyLarge().copyWith(fontSize: 18),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiaryLight),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // Replay Demo Mode (Section 21 / Hackathon Demo Reliability)
              Semantics(
                button: true,
                label: 'Run Replay Demo Mode with Pre-recorded Keypoints and EMG Data',
                child: OutlinedButton.icon(
                  onPressed: () {
                    context.go('/patient/session?replay=true');
                  },
                  icon: const Icon(Icons.fast_forward_rounded, size: 26),
                  label: const Text('REPLAY DEMO MODE'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.secondary,
                    side: const BorderSide(color: AppColors.secondary, width: 2),
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Last Completed Session Summary Note
              if (latestSession != null)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.cardBorderLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.history_rounded, size: 30, color: AppColors.primary),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Previous Session',
                              style: AppTypography.clinicalCaption(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${latestSession.correctReps} / ${latestSession.completedReps} correct • ${latestSession.adherence.toStringAsFixed(0)}% adherence',
                              style: AppTypography.patientBodyMedium().copyWith(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
