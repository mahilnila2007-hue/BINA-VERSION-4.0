import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/color_palette.dart';
import '../../core/theme/typography.dart';
import '../auth/auth_provider.dart';
import 'prescription_builder_dialog.dart';

/// Clinical Monitoring Dashboard for Dr. Priya.
/// Displays adherence overview, patient recovery status cards, and quick actions.
class TherapistDashboardScreen extends ConsumerWidget {
  const TherapistDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patients = ref.watch(patientRepositoryProvider).getAllPatients();
    final isOnline = ref.watch(isOnlineProvider);
    final sessions = ref.watch(patientSessionsProvider);

    // Latest session for Arun
    final arunSession = sessions.isNotEmpty ? sessions.first : null;

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
                Icons.medical_services_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Clinical Portal',
                  style: AppTypography.headingMedium().copyWith(fontSize: 18),
                ),
                Text(
                  AppConstants.appName,
                  style: AppTypography.clinicalCaption(),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Switch Role Button
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.swap_horiz_rounded, size: 20),
            label: const Text('Switch Role'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => const PrescriptionBuilderDialog(),
          );
        },
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('New Prescription', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Therapist Header (Section 24)
              Text(
                'Good morning, Dr. Priya',
                style: AppTypography.headingLarge().copyWith(fontSize: 28),
              ),
              const SizedBox(height: 6),
              Text(
                'Patient adherence overview',
                style: AppTypography.patientBodyMedium().copyWith(
                  color: AppColors.textSecondaryLight,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),

              // Cloud Sync Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorderLight),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: isOnline ? AppColors.success : AppColors.secondary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isOnline ? 'Cloud Synced • Firebase Realtime DB Active' : 'Offline Queue Active • Local Storage',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isOnline ? AppColors.onSuccess : AppColors.onSecondaryContainer,
                        ),
                      ),
                    ),
                    Switch(
                      value: isOnline,
                      activeTrackColor: AppColors.primary,
                      onChanged: (val) {
                        ref.read(isOnlineProvider.notifier).toggle();
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // KPI Summary Row
              Row(
                children: [
                  _buildKpiCard(
                    title: 'Active Patients',
                    value: '${patients.length}',
                    subtitle: 'All monitored',
                    icon: Icons.people_alt_rounded,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 14),
                  _buildKpiCard(
                    title: 'Avg Adherence',
                    value: '87%',
                    subtitle: '+7% this week',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.success,
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Patient Cards Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Active Patients',
                    style: AppTypography.headingMedium().copyWith(fontSize: 20),
                  ),
                  Text(
                    '${patients.length} assigned',
                    style: AppTypography.clinicalCaption(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Patient Card 1: Arun (Section 24 Specification - Green: Good)
              _buildPatientAdherenceCard(
                context: context,
                ref: ref,
                patientName: 'ARUN',
                condition: 'Knee Rehabilitation (Post-TKR)',
                adherence: arunSession?.adherence ?? 87.0,
                correctReps: arunSession?.correctReps ?? 26,
                totalReps: arunSession?.prescribedReps ?? 30,
                lastSessionTime: 'Today, 10:42 AM',
                status: _AdherenceStatus.good,
                onTap: () {
                  context.go('/therapist/patient/${AppConstants.defaultPatientId}');
                },
              ),

              const SizedBox(height: 16),

              // Patient Card 2: Meera (Amber: Attention Needed)
              _buildPatientAdherenceCard(
                context: context,
                ref: ref,
                patientName: 'MEERA',
                condition: 'Rotator Cuff Recovery',
                adherence: 64.0,
                correctReps: 16,
                totalReps: 25,
                lastSessionTime: 'Yesterday, 4:15 PM',
                status: _AdherenceStatus.attention,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demo patient: View Arun for full multi-day analytics.')),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Patient Card 3: Kabir (Red: Action Required)
              _buildPatientAdherenceCard(
                context: context,
                ref: ref,
                patientName: 'KABIR',
                condition: 'ACL Reconstruction Day 7',
                adherence: 42.0,
                correctReps: 10,
                totalReps: 25,
                lastSessionTime: '2 days ago',
                status: _AdherenceStatus.actionRequired,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Action Required: Patient missed last 2 sessions.')),
                  );
                },
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.cardBorderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: AppTypography.clinicalCaption()),
                Icon(icon, size: 22, color: color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTypography.headingLarge().copyWith(fontSize: 28, color: color),
            ),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientAdherenceCard({
    required BuildContext context,
    required WidgetRef ref,
    required String patientName,
    required String condition,
    required double adherence,
    required int correctReps,
    required int totalReps,
    required String lastSessionTime,
    required _AdherenceStatus status,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.cardBorderLight, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.person_rounded, color: AppColors.primary, size: 26),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: AppTypography.headingMedium().copyWith(fontSize: 20),
                          ),
                          Text(
                            condition,
                            style: AppTypography.clinicalCaption(),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Status Badge with icon + color + text (Section 24: Never color alone)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: status.backgroundColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: status.color, width: 1.2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 16, color: status.color),
                        const SizedBox(width: 6),
                        Text(
                          status.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: status.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Metrics Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Today's adherence", style: AppTypography.clinicalCaption()),
                      const SizedBox(height: 2),
                      Text(
                        '${adherence.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: status.color,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Movement Accuracy', style: AppTypography.clinicalCaption()),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, size: 18, color: status.color),
                          const SizedBox(width: 6),
                          Text(
                            '$correctReps / $totalReps correct reps',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.cardBorderLight),
              const SizedBox(height: 12),

              // Footer: Last session timestamp + drilldown indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last session: $lastSessionTime',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                  Row(
                    children: const [
                      Text(
                        'View Recovery',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.primary),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _AdherenceStatus {
  good(
    label: 'Good Adherence',
    color: AppColors.success,
    backgroundColor: AppColors.successContainer,
    icon: Icons.check_circle_rounded,
  ),
  attention(
    label: 'Attention Needed',
    color: AppColors.warning,
    backgroundColor: AppColors.warningContainer,
    icon: Icons.error_outline_rounded,
  ),
  actionRequired(
    label: 'Action Required',
    color: AppColors.error,
    backgroundColor: AppColors.errorContainer,
    icon: Icons.warning_rounded,
  );

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;

  const _AdherenceStatus({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });
}
