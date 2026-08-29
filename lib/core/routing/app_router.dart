import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_routes.dart';
import '../../features/splash/splash_screen.dart';
import '../../features/authentication/screens/login_screen.dart';
import '../../features/authentication/screens/otp_verification_screen.dart';
import '../../features/onboarding/screens/onboarding_screen.dart';
import '../../features/family/screens/invite_child_screen.dart';
import '../../features/family/screens/join_family_screen.dart';
import '../../features/parent/screens/parent_shell_screen.dart';
import '../../features/parent/screens/parent_dashboard_screen.dart';
import '../../features/parent/screens/parent_children_screen.dart';
import '../../features/parent/screens/parent_reports_screen.dart';
import '../../features/parent/screens/parent_triggers_screen.dart';
import '../../features/parent/screens/parent_ai_screen.dart';
import '../../features/parent/screens/parent_settings_screen.dart';
import '../../features/child/screens/child_shell_screen.dart';
import '../../features/child/screens/child_dashboard_screen.dart';
import '../../features/child/screens/child_insights_screen.dart';
import '../../features/child/screens/child_missions_screen.dart';
import '../../features/child/screens/child_progress_screen.dart';
import '../../features/child/screens/child_ai_screen.dart';
import '../../features/child/screens/child_settings_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.otpVerify,
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return OtpVerificationScreen(
            displayName: extra?['displayName'] as String?,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.parentInviteChild,
        builder: (context, state) => const InviteChildScreen(),
      ),
      GoRoute(
        path: AppRoutes.childJoinFamily,
        builder: (context, state) => const JoinFamilyScreen(),
      ),

      // Parent Navigation Shell
      ShellRoute(
        builder: (context, state, child) => ParentShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.parent,
            builder: (context, state) => const ParentDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentChildren,
            builder: (context, state) => const ParentChildrenScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentReports,
            builder: (context, state) => const ParentReportsScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentTriggers,
            builder: (context, state) => const ParentTriggersScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentAi,
            builder: (context, state) => const ParentAiScreen(),
          ),
          GoRoute(
            path: AppRoutes.parentSettings,
            builder: (context, state) => const ParentSettingsScreen(),
          ),
        ],
      ),

      // Child Navigation Shell
      ShellRoute(
        builder: (context, state, child) => ChildShellScreen(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.child,
            builder: (context, state) => const ChildDashboardScreen(),
          ),
          GoRoute(
            path: AppRoutes.childInsights,
            builder: (context, state) => const ChildInsightsScreen(),
          ),
          GoRoute(
            path: AppRoutes.childMissions,
            builder: (context, state) => const ChildMissionsScreen(),
          ),
          GoRoute(
            path: AppRoutes.childProgress,
            builder: (context, state) => const ChildProgressScreen(),
          ),
          GoRoute(
            path: AppRoutes.childAi,
            builder: (context, state) => const ChildAiScreen(),
          ),
          GoRoute(
            path: AppRoutes.childSettings,
            builder: (context, state) => const ChildSettingsScreen(),
          ),
        ],
      ),
    ],
  );
});
