import 'package:intl/intl.dart';

/// Formatting helpers for dates, durations, and numbers.
class AppFormatters {
  static final DateFormat sessionDate = DateFormat('EEE, MMM d • h:mm a');
  static final DateFormat shortDate = DateFormat('MMM d');
  static final DateFormat timeOnly = DateFormat('h:mm a');

  static String formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  static String formatPercent(double ratio) {
    return '${ratio.toStringAsFixed(0)}%';
  }

  static String formatAngle(double degrees) {
    return '${degrees.toStringAsFixed(0)}°';
  }
}
