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
    if (location.startsWith(AppRoutes.childInsights)) return 1;
    if (location.startsWith(AppRoutes.childMissions)) return 2;
    if (location.startsWith(AppRoutes.childProgress)) return 3;
    if (location.startsWith(AppRoutes.childAi)) return 4;
    if (location.startsWith(AppRoutes.childSettings)) return 5;
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(AppRoutes.child);
        break;
      case 1:
        context.go(AppRoutes.childInsights);
        break;
      case 2:
        context.go(AppRoutes.childMissions);
        break;
      case 3:
        context.go(AppRoutes.childProgress);
        break;
      case 4:
        context.go(AppRoutes.childAi);
        break;
      case 5:
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
        indicatorColor: AppTheme.childSecondary.withAlpha((0.2 * 255).round()),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon:
                Icon(Icons.home_rounded, color: AppTheme.childSecondary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline_rounded),
            selectedIcon:
                Icon(Icons.lightbulb_rounded, color: AppTheme.childSecondary),
            label: 'Insights',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon:
                Icon(Icons.flag_rounded, color: AppTheme.childSecondary),
            label: 'Missions',
          ),
          NavigationDestination(
            icon: Icon(Icons.military_tech_outlined),
            selectedIcon: Icon(Icons.military_tech_rounded,
                color: AppTheme.childSecondary),
            label: 'Progress',
          ),
          NavigationDestination(
            icon: Icon(Icons.smart_toy_outlined),
            selectedIcon:
                Icon(Icons.smart_toy_rounded, color: AppTheme.childSecondary),
            label: 'Buddy AI',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon:
                Icon(Icons.tune_rounded, color: AppTheme.childSecondary),
            label: 'Me',
          ),
        ],
      ),
    );
  }
}
