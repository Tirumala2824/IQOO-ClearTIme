import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class ChildShellScreen extends StatelessWidget {
  final Widget child;

  const ChildShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location == AppRoutes.child) return 0;
    if (location.startsWith(AppRoutes.childGoals) ||
        location.startsWith(AppRoutes.childMissions)) {
      return 1;
    }
    if (location.startsWith(AppRoutes.childProgress) ||
        location.startsWith(AppRoutes.childInsights)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.childSettings) ||
        location.startsWith(AppRoutes.childPrivacyCenter)) {
      return 3;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.child);
        break;
      case 1:
        context.go(AppRoutes.childGoals);
        break;
      case 2:
        context.go(AppRoutes.childProgress);
        break;
      case 3:
        context.go(AppRoutes.childSettings);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => _onItemTapped(index, context),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: AppTheme.childSecondary.withAlpha((0.2 * 255).round()),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home_rounded, color: AppTheme.childSecondary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_rounded),
            selectedIcon:
                Icon(Icons.track_changes_rounded, color: AppTheme.childSecondary),
            label: 'Goal',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded,
                color: AppTheme.childSecondary),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.face_outlined),
            selectedIcon:
                Icon(Icons.face_rounded, color: AppTheme.childSecondary),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
