import 'package:flutter/material.dart';
import '../../core/theme/color_palette.dart';

/// Form evaluation verdict for an individual repetition.
enum RepVerdict {
  correct,
  tooShallow,
  overshoot,
  tooFast,
  lowMuscleEngagement,
  unknown;

  String get displayName {
    switch (this) {
      case RepVerdict.correct:
        return 'GOOD REP';
      case RepVerdict.tooShallow:
        return 'BEND A LITTLE MORE';
      case RepVerdict.overshoot:
        return "DON'T BEND THAT FAR";
      case RepVerdict.tooFast:
        return 'SLOW DOWN';
      case RepVerdict.lowMuscleEngagement:
        return 'USE YOUR MUSCLE';
      case RepVerdict.unknown:
        return 'READY';
    }
  }

  String get voiceCue {
    switch (this) {
      case RepVerdict.correct:
        return 'Good rep';
      case RepVerdict.tooShallow:
        return 'Bend a little more';
      case RepVerdict.overshoot:
        return "Don't bend that far";
      case RepVerdict.tooFast:
        return 'Slow down';
      case RepVerdict.lowMuscleEngagement:
        return 'Use your muscle';
      case RepVerdict.unknown:
        return '';
    }
  }

  Color get color {
    switch (this) {
      case RepVerdict.correct:
        return AppColors.success;
      case RepVerdict.tooShallow:
      case RepVerdict.lowMuscleEngagement:
        return AppColors.warning;
      case RepVerdict.overshoot:
      case RepVerdict.tooFast:
        return AppColors.error;
      case RepVerdict.unknown:
        return AppColors.info;
    }
  }

  IconData get icon {
    switch (this) {
      case RepVerdict.correct:
        return Icons.check_circle_rounded;
      case RepVerdict.tooShallow:
        return Icons.arrow_downward_rounded;
      case RepVerdict.overshoot:
        return Icons.warning_amber_rounded;
      case RepVerdict.tooFast:
        return Icons.speed_rounded;
      case RepVerdict.lowMuscleEngagement:
        return Icons.fitness_center_rounded;
      case RepVerdict.unknown:
        return Icons.info_outline_rounded;
    }
  }

  static RepVerdict fromString(String val) {
    switch (val.toUpperCase()) {
      case 'CORRECT':
        return RepVerdict.correct;
      case 'TOO_SHALLOW':
        return RepVerdict.tooShallow;
      case 'OVERSHOOT':
        return RepVerdict.overshoot;
      case 'TOO_FAST':
        return RepVerdict.tooFast;
      case 'LOW_MUSCLE_ENGAGEMENT':
        return RepVerdict.lowMuscleEngagement;
      default:
        return RepVerdict.unknown;
    }
  }
}
