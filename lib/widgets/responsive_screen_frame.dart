import 'package:flutter/material.dart';
import '../core/theme/color_palette.dart';

/// Wraps any screen in a responsive, beautifully aligned mobile canvas.
/// On desktop and wide displays, it cleanly centers the content within a max-width container (520dp)
/// with a studio background and subtle drop shadow.
/// On mobile devices, it seamlessly fills the native viewport.
class ResponsiveScreenFrame extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final Color backgroundColor;

  const ResponsiveScreenFrame({
    super.key,
    required this.child,
    this.maxWidth = 520,
    this.backgroundColor = AppPalette.warmWhite,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > maxWidth + 40) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F2F5),
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxWidth),
                child: Container(
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.symmetric(
                      vertical: BorderSide(
                        color: Colors.black.withOpacity(0.08),
                        width: 1,
                      ),
                    ),
                  ),
                  child: child,
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
