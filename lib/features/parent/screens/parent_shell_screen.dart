import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';

class ParentShellScreen extends StatelessWidget {
  final Widget child;

  const ParentShellScreen({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location == AppRoutes.parent) return 0;
    if (location.startsWith(AppRoutes.parentChildren)) return 1;
    if (location.startsWith(AppRoutes.parentReports)) return 2;
    if (location.startsWith(AppRoutes.parentTriggers)) return 3;
    if (location.startsWith(AppRoutes.parentAi)) return 4;
    if (location.startsWith(AppRoutes.parentSettings)) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.parent);
        break;
      case 1:
        context.go(AppRoutes.parentChildren);
        break;
      case 2:
        context.go(AppRoutes.parentReports);
        break;
      case 3:
        context.go(AppRoutes.parentTriggers);
        break;
      case 4:
        context.go(AppRoutes.parentAi);
        break;
      case 5:
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
        indicatorColor: AppTheme.parentPrimary.withAlpha((0.15 * 255).round()),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon:
                Icon(Icons.dashboard_rounded, color: AppTheme.parentPrimary),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon:
                Icon(Icons.people_rounded, color: AppTheme.parentPrimary),
            label: 'Children',
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            selectedIcon:
                Icon(Icons.assessment_rounded, color: AppTheme.parentPrimary),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_active_outlined),
            selectedIcon: Icon(Icons.notifications_active_rounded,
                color: AppTheme.parentPrimary),
            label: 'Triggers',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon:
                Icon(Icons.psychology_rounded, color: AppTheme.parentPrimary),
            label: 'Local AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon:
                Icon(Icons.settings_rounded, color: AppTheme.parentPrimary),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
