import 'package:flutter/material.dart';

/// Curated, clinical-yet-warm color system for ReHabRep.
/// Follows Section 19:
/// - Primary: Energetic warm orange (#FF6B00 / #EA580C)
/// - Background: Pale warm white / soft off-white (#FBFBF9)
/// - Secondary: Fresh soft teal (#0D9488), fresh green (#10B981), muted blue (#3B82F6)
/// - Feedback: Green (Correct), Amber/Orange (Adjustment required), Red (Stop / safety)
/// Never relies on color alone (always paired with icons/text).
class AppColors {
  // Primary Energetic Warm Orange (Section 19)
  static const Color primary = Color(0xFFEA580C); // Warm Orange Accent
  static const Color primaryLight = Color(0xFFF97316); // Bright Orange
  static const Color primaryDark = Color(0xFF9A3412); // Deep Terracotta
  static const Color primaryContainer = Color(0xFFFFEDD5); // Soft Orange Tint
  static const Color onPrimaryContainer = Color(0xFF7C2D12);

  // Secondary Fresh Teal & Muted Blue
  static const Color secondary = Color(0xFF0D9488); // Fresh Soft Teal
  static const Color secondaryLight = Color(0xFF14B8A6);
  static const Color secondaryDark = Color(0xFF115E59);
  static const Color secondaryContainer = Color(0xFFCCFBF1);
  static const Color onSecondaryContainer = Color(0xFF134E4A);

  // Background & Surfaces (Pale warm white / soft off-white)
  static const Color backgroundLight = Color(0xFFFBFBF9);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceVariantLight = Color(0xFFF3F3EE);
  static const Color cardBorderLight = Color(0xFFE5E5DF);

  // Dark Mode Surfaces (for Camera Overlay & Viewfinder HUD)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color cardBorderDark = Color(0xFF475569);

  // High-Contrast Text
  static const Color textPrimaryLight = Color(0xFF1C1917);
  static const Color textSecondaryLight = Color(0xFF57534E);
  static const Color textTertiaryLight = Color(0xFF78716C);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFCBD5E1);
  static const Color textTertiaryDark = Color(0xFF94A3B8);

  // Clinical Semantics (always paired with icons & text)
  static const Color success = Color(0xFF10B981); // Emerald Green: Good rep / completed
  static const Color successContainer = Color(0xFFD1FAE5);
  static const Color onSuccess = Color(0xFF065F46);

  static const Color warning = Color(0xFFF59E0B); // Amber / Warm Adjustment: Bend a little more
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarning = Color(0xFF92400E);

  static const Color error = Color(0xFFEF4444); // Crimson: Stop / safety limit
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onError = Color(0xFF991B1B);

  static const Color info = Color(0xFF3B82F6); // Muted Blue: Informational
  static const Color infoContainer = Color(0xFFDBEAFE);

  // Bio-signal / Hardware Semantics
  static const Color emgColor = Color(0xFF8B5CF6); // Purple: Muscle activation
  static const Color heartRateColor = Color(0xFFF43F5E); // Rose: Pulse / HR
  static const Color spo2Color = Color(0xFF06B6D4); // Cyan: Oxygen saturation
  static const Color environmentColor = Color(0xFF10B981); // Emerald: Ambient
}

/// Palette class with semantic convenience aliases.
class AppPalette {
  static const Color orange = AppColors.primary;
  static const Color warmWhite = AppColors.backgroundLight;
  static const Color charcoalDark = AppColors.textPrimaryLight;
  static const Color charcoalMuted = AppColors.textSecondaryLight;
  static const Color freshGreen = AppColors.success;
  static const Color amberWarning = AppColors.warning;
  static const Color coralRed = AppColors.error;
  static const Color tealAccent = AppColors.secondary;
  static const Color mutedBlue = AppColors.info;
}

