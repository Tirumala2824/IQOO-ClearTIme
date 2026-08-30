import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';

/// Child Navigation Shell providing 4 clear, welcoming destinations.
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
    if (location.startsWith(AppRoutes.childAi)) {
      return 2;
    }
    if (location.startsWith(AppRoutes.childProgress) ||
        location.startsWith(AppRoutes.childInsights)) {
      return 3;
    }
    if (location.startsWith(AppRoutes.childSettings) ||
        location.startsWith(AppRoutes.childAiSettings) ||
        location.startsWith(AppRoutes.childPrivacyCenter)) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.child);
        break;
      case 1:
        context.go(AppRoutes.childMissions);
        break;
      case 2:
        context.go(AppRoutes.childAi);
        break;
      case 3:
        context.go(AppRoutes.childProgress);
        break;
      case 4:
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
        elevation: 6,
        indicatorColor: AppColors.childSecondary.withAlpha((0.18 * 255).round()),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.childSecondary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes_rounded, color: AppColors.childSecondary),
            label: 'Activities',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon: Icon(Icons.smart_toy_rounded, color: AppColors.childSecondary),
            label: 'AI Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events_rounded, color: AppColors.childSecondary),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.childSecondary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
