import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';

/// Parent Navigation Shell providing seamless, accessible 5-destination navigation.
class ParentShellScreen extends StatelessWidget {
  final Widget child;

  const ParentShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location == AppRoutes.parent) return 0;
    if (location.startsWith(AppRoutes.parentTasks)) return 1;
    if (location.startsWith(AppRoutes.parentChildren)) return 2;
    if (location.startsWith(AppRoutes.parentReports)) return 3;
    if (location.startsWith(AppRoutes.parentSettings) ||
        location.startsWith(AppRoutes.parentTriggers) ||
        location.startsWith(AppRoutes.parentAi)) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.parent);
        break;
      case 1:
        context.go(AppRoutes.parentTasks);
        break;
      case 2:
        context.go(AppRoutes.parentChildren);
        break;
      case 3:
        context.go(AppRoutes.parentReports);
        break;
      case 4:
        context.go(AppRoutes.parentSettings);
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
        indicatorColor: AppColors.parentPrimary.withAlpha((0.14 * 255).round()),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.parentPrimary),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt_rounded, color: AppColors.parentPrimary),
            label: 'Activities',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded, color: AppColors.parentPrimary),
            label: 'Children',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon: Icon(Icons.assessment_rounded, color: AppColors.parentPrimary),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.settings_rounded, color: AppColors.parentPrimary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
