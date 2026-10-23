import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/color_palette.dart';
import '../../domain/services/haptic_service.dart';
import '../../domain/services/tts_service.dart';
import '../../widgets/app_logo.dart';
import '../auth/auth_provider.dart';

/// User Profile Screen (Section 22).
/// Contains: Name, Email, Profile Picture, Exercise Preferences (Voice Coaching,
/// Haptics, Camera settings), Privacy, and Sign Out.
class UserProfileScreen extends ConsumerWidget {
  const UserProfileScreen({super.key});

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Sign Out',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppPalette.charcoalDark,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out of ReHabRep?',
          style: TextStyle(fontSize: 16, color: AppPalette.charcoalMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppPalette.charcoalMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.coralRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(currentUserProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/sign-in');
              }
            },
            child:
                const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPrivacyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.privacy_tip_outlined, color: AppPalette.orange),
            SizedBox(width: 10),
            Text('Privacy & Data',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            'ReHabRep processes video frames locally on your device using on-device YOLO Pose Estimation. '
            'Camera feeds are NEVER transmitted to external servers. '
            'Only computed numerical metrics (repetition counts, joint angles, and session adherence) '
            'are securely synced for your recovery records.',
            style: TextStyle(fontSize: 14, height: 1.5),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppPalette.orange),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Understood', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final patient = ref.watch(currentPatientProvider);

    final name = user?.name ?? patient?.name ?? 'Arun';
    final email = user?.email ?? 'arun@rehabrep.com';
    final age = user?.age ?? patient?.age ?? 68;

    final voiceCoaching = user?.voiceCoachingEnabled ?? true;
    final haptics = user?.hapticFeedbackEnabled ?? true;
    final isFrontCamera = user?.isFrontCamera ?? true;

    return Scaffold(
      backgroundColor: AppPalette.warmWhite,
      appBar: AppBar(
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppPalette.charcoalDark,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black.withOpacity(0.06)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      offset: const Offset(0, 3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppPalette.orange.withOpacity(0.14),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppPalette.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppPalette.charcoalDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            email,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppPalette.charcoalMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppPalette.warmWhite,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Age: $age • Knee Rehabilitation',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppPalette.charcoalDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: Exercise Preferences
              const Text(
                'Exercise Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoalDark,
                ),
              ),
              const SizedBox(height: 12),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    // Voice Coaching Toggle
                    SwitchListTile(
                      activeColor: AppPalette.orange,
                      title: const Text(
                        'Voice Coaching',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoalDark,
                        ),
                      ),
                      subtitle: const Text(
                        'Spoken feedback ("Good rep", "Bend more") with 2–4s cooldown',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.charcoalMuted,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppPalette.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.record_voice_over_rounded,
                            color: AppPalette.orange),
                      ),
                      value: voiceCoaching,
                      onChanged: (val) {
                        ref
                            .read(currentUserProvider.notifier)
                            .updatePreferences(voiceCoaching: val);
                        TtsService().setEnabled(val);
                      },
                    ),
                    const Divider(height: 1, indent: 64),

                    // Haptic Feedback Toggle
                    SwitchListTile(
                      activeColor: AppPalette.orange,
                      title: const Text(
                        'Haptic Vibration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoalDark,
                        ),
                      ),
                      subtitle: const Text(
                        'Tactile vibration pulses on rep completion',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.charcoalMuted,
                        ),
                      ),
                      secondary: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppPalette.tealAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.vibration_rounded,
                            color: AppPalette.tealAccent),
                      ),
                      value: haptics,
                      onChanged: (val) {
                        ref
                            .read(currentUserProvider.notifier)
                            .updatePreferences(haptics: val);
                        HapticService().setEnabled(val);
                      },
                    ),
                    const Divider(height: 1, indent: 64),

                    // Camera Preference (Front / Back)
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppPalette.mutedBlue.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.flip_camera_ios_rounded,
                            color: AppPalette.mutedBlue),
                      ),
                      title: const Text(
                        'Camera Orientation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoalDark,
                        ),
                      ),
                      subtitle: Text(
                        isFrontCamera ? 'Front Camera (Mirror view)' : 'Back Camera',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppPalette.charcoalMuted,
                        ),
                      ),
                      trailing: TextButton(
                        onPressed: () {
                          ref
                              .read(currentUserProvider.notifier)
                              .updatePreferences(isFrontCamera: !isFrontCamera);
                        },
                        child: Text(
                          isFrontCamera ? 'Switch to Back' : 'Switch to Front',
                          style: const TextStyle(
                            color: AppPalette.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // SECTION: Support & Privacy
              const Text(
                'Support & Privacy',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppPalette.charcoalDark,
                ),
              ),
              const SizedBox(height: 12),

              Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.black.withOpacity(0.06)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppPalette.freshGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.security_rounded,
                            color: AppPalette.freshGreen),
                      ),
                      title: const Text(
                        'Privacy & On-Device Processing',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoalDark,
                        ),
                      ),
                      subtitle: const Text(
                        'Camera frames stay strictly on your phone',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.charcoalMuted,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPrivacyDialog(context),
                    ),
                    const Divider(height: 1, indent: 64),
                    ListTile(
                      leading: const AppLogo(
                        size: 36,
                        isCircle: true,
                        showBorder: true,
                      ),
                      title: const Text(
                        'About ReHabRep',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoalDark,
                        ),
                      ),
                      subtitle: const Text(
                        'Version 3.0 • AI Form Coach',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppPalette.charcoalMuted,
                        ),
                      ),
                      trailing: const Text(
                        'v3.0.0',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoalMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // SIGN OUT BUTTON
              SizedBox(
                height: 54,
                child: OutlinedButton.icon(
                  onPressed: () => _showSignOutDialog(context, ref),
                  icon: const Icon(Icons.logout_rounded, color: AppPalette.coralRed),
                  label: const Text(
                    'SIGN OUT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppPalette.coralRed,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppPalette.coralRed.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
