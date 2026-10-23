import 'package:flutter/services.dart';

/// Accessible tactile haptic feedback service.
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  static bool _enabled = true;
  bool get isEnabled => _enabled;

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// Single firm pulse for a successful, correct repetition
  static void success() {
    if (!_enabled) return;
    HapticFeedback.mediumImpact();
  }

  /// Double tap warning for shallow or form adjustments
  static void warning() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 140), () {
      if (_enabled) HapticFeedback.lightImpact();
    });
  }

  /// Triple alert for overshoot / safety limits
  static void error() {
    if (!_enabled) return;
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!_enabled) return;
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 120), () {
        if (_enabled) HapticFeedback.heavyImpact();
      });
    });
  }

  /// Subtle click for button selections
  static void selection() {
    if (!_enabled) return;
    HapticFeedback.selectionClick();
  }
}
