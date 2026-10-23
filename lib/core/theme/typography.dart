import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'color_palette.dart';

/// Elderly-First Accessible Typography System for ReHabRep.
/// - Minimum body text: 20sp for patient interfaces.
/// - Large titles: 28–34sp.
/// - Repetition counter: 96sp+.
/// - High legibility, sans-serif, high contrast.
class AppTypography {
  // Ultra-large Rep Counter
  static TextStyle repCounter({Color color = Colors.white}) =>
      GoogleFonts.outfit(
        fontSize: 96,
        fontWeight: FontWeight.w900,
        height: 1.0,
        letterSpacing: -2.0,
        color: color,
      );

  // Large Angle Display
  static TextStyle angleDisplay({Color color = Colors.white}) =>
      GoogleFonts.outfit(
        fontSize: 64,
        fontWeight: FontWeight.w800,
        height: 1.0,
        color: color,
      );

  // Big Section Headings (28–34sp)
  static TextStyle headingLarge({bool isDark = false}) =>
      GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.2,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      );

  static TextStyle headingMedium({bool isDark = false}) =>
      GoogleFonts.outfit(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      );

  // Elderly-First Body Text (>= 20sp for Patient readability)
  static TextStyle patientBodyLarge({bool isDark = false}) =>
      GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.4,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      );

  static TextStyle patientBodyMedium({bool isDark = false}) =>
      GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      );

  // Feedback Banner Text
  static TextStyle feedbackBanner({Color color = Colors.white}) =>
      GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color,
      );

  // Large Button Labels (Touchable, Clear, 22sp)
  static TextStyle buttonLabel({Color color = Colors.white}) =>
      GoogleFonts.outfit(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: color,
      );

  // Clinical / Dashboard Standard Body
  static TextStyle clinicalBody({bool isDark = false}) =>
      GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      );

  static TextStyle clinicalCaption({bool isDark = false}) =>
      GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
      );
}
