import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/color_palette.dart';

/// Persistent navigation shell for ReHabRep.
/// Keeps the bottom navigation bar permanently visible across all 5 primary user tabs.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({
    super.key,
    required this.navigationShell,
  });

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;

        Widget content = Scaffold(
          backgroundColor: AppPalette.warmWhite,
          body: navigationShell,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, -3),
                  blurRadius: 12,
                ),
              ],
              border: Border(
                top: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
            ),
            child: SafeArea(
              child: NavigationBar(
                height: 70,
                backgroundColor: Colors.white,
                elevation: 0,
                indicatorColor: AppPalette.orange.withOpacity(0.16),
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (index) => _onTap(context, index),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined, size: 26),
                    selectedIcon: Icon(Icons.home_rounded, color: AppPalette.orange, size: 26),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.fitness_center_outlined, size: 26),
                    selectedIcon: Icon(Icons.fitness_center_rounded, color: AppPalette.orange, size: 26),
                    label: 'Exercises',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights_outlined, size: 26),
                    selectedIcon: Icon(Icons.insights_rounded, color: AppPalette.orange, size: 26),
                    label: 'Progress',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.smart_toy_outlined, size: 26),
                    selectedIcon: Icon(Icons.smart_toy_rounded, color: AppPalette.orange, size: 26),
                    label: 'AI Coach',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline, size: 26),
                    selectedIcon: Icon(Icons.person_rounded, color: AppPalette.orange, size: 26),
                    label: 'Profile',
                  ),
                ],
              ),
            ),
          ),
        );

        if (isWide) {
          return Scaffold(
            backgroundColor: const Color(0xFFF0F2F5),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppPalette.warmWhite,
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
                  child: content,
                ),
              ),
            ),
          );
        }

        return content;
      },
    );
  }
}

