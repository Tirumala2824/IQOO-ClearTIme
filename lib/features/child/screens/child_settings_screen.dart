import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildSettingsScreen extends ConsumerWidget {
  const ChildSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childState = ref.watch(childDashboardControllerProvider);
    final profile = childState.profile;
    final family = childState.family;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('My Profile & Settings ⚙️'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor:
                        AppTheme.childPrimary.withAlpha((0.15 * 255).round()),
                    child: const Icon(
                      Icons.sentiment_very_satisfied_rounded,
                      color: AppTheme.childPrimary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.nickname ?? 'Explorer',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          family?.name != null
                              ? 'Member of ${family!.name}'
                              : 'Paired Family',
                          style: const TextStyle(
                              color: AppTheme.neutralMuted, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Privacy Protection',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.childTextDark,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: const [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield_outlined,
                        color: AppTheme.childSecondary),
                    title: Text('Data Minimization Guarantee'),
                    subtitle: Text(
                        'Your individual screen logs and chats are never sent to cloud servers.'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
            label: const Text('Sign Out',
                style: TextStyle(color: AppTheme.errorRed)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.errorRed),
            ),
          ),
        ],
      ),
    );
  }
}
