import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../authentication/controllers/auth_controller.dart';
import '../parent/controllers/parent_dashboard_controller.dart';
import '../child/controllers/child_dashboard_controller.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  Future<void> _checkInitialState() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;

    try {
      final authState = ref.read(authControllerProvider);
      final user = authState.user;

      if (user == null) {
        context.go(AppRoutes.login);
        return;
      }

      if (user.isParent) {
        await ref
            .read(parentDashboardControllerProvider.notifier)
            .loadDashboard(user.id);
        final parentState = ref.read(parentDashboardControllerProvider);
        if (!mounted) return;
        if (!parentState.hasFamily) {
          context.go(AppRoutes.onboarding);
        } else {
          context.go(AppRoutes.parent);
        }
      } else {
        await ref
            .read(childDashboardControllerProvider.notifier)
            .loadDashboard(user.id);
        final childState = ref.read(childDashboardControllerProvider);
        if (!mounted) return;
        if (!childState.hasFamily) {
          context.go(AppRoutes.childJoinFamily);
        } else {
          context.go(AppRoutes.child);
        }
      }
    } catch (_) {
      if (mounted) {
        context.go(AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.parentPrimary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.2 * 255).round()),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.hourglass_top_rounded,
                size: 52,
                color: AppTheme.parentPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha((0.85 * 255).round()),
                  ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
