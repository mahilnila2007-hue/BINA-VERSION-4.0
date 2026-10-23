import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Accessibility utilities to support TalkBack, semantic labels,
/// and high-contrast elderly navigation.
class AccessibilityHelper {
  /// Announce message to TalkBack / screen reader.
  static void announce(BuildContext context, String message) {
    if (message.isEmpty) return;
    try {
      final view = View.of(context);
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    } catch (_) {
      // Graceful fallback for older platforms
    }
  }

  /// Wraps a widget in an accessible button card with touch target >= 64dp.
  static Widget largeTouchableCard({
    required Widget child,
    required VoidCallback onTap,
    required String semanticLabel,
    Color? backgroundColor,
    BorderSide? borderSide,
    EdgeInsetsGeometry padding = const EdgeInsets.all(20),
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        elevation: 2,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 68),
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: borderSide != null ? Border.fromBorderSide(borderSide) : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
