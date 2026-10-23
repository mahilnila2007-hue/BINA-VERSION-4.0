import 'package:flutter/material.dart';
import '../core/theme/color_palette.dart';

/// Reusable App Logo Widget for ReHabRep.
/// Displays the official pull-up ECG recovery silhouette logo.
class AppLogo extends StatelessWidget {
  final double size;
  final double borderRadius;
  final bool showBorder;
  final bool isCircle;

  const AppLogo({
    super.key,
    this.size = 72,
    this.borderRadius = 18,
    this.showBorder = true,
    this.isCircle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.black,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircle ? null : BorderRadius.circular(borderRadius),
        border: showBorder
            ? Border.all(
                color: AppPalette.orange,
                width: 2.2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: AppPalette.orange.withOpacity(0.25),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: isCircle
          ? ClipOval(
              child: Image.asset(
                'assets/images/app_logo_square.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to silhouette icon
                  return Center(
                    child: Icon(
                      Icons.accessibility_new_rounded,
                      size: size * 0.6,
                      color: AppPalette.orange,
                    ),
                  );
                },
              ),
            )
          : ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.asset(
                'assets/images/app_logo_square.png',
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback to silhouette icon
                  return Center(
                    child: Icon(
                      Icons.accessibility_new_rounded,
                      size: size * 0.6,
                      color: AppPalette.orange,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
