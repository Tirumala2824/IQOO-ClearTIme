import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
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
            'On-Device AI Buddy',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.childTextDark,
                ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined,
                  color: AppTheme.childSecondary, size: 28),
              title: const Text(
                'My Wellbeing Buddy Settings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                '100% private, runs offline on this phone with zero cloud AI',
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.neutralMuted),
              onTap: () => context.push(AppRoutes.localAiSettings),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Privacy & Local Storage',
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
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.shield_outlined,
                        color: AppTheme.childSecondary),
                    title: Text('100% On-Device Storage'),
                    subtitle: Text(
                        'Your usage records, chats, and reflections are encrypted and stay on this phone.'),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.auto_delete_outlined,
                        color: AppTheme.warningOrange),
                    title: const Text('Auto-Retention Cleanup'),
                    subtitle: const Text('Local records older than 30 days are automatically deleted.'),
                    trailing: TextButton(
                      onPressed: () async {
                        final count = await ref.read(localUsageStoreProvider).deleteExpiredUsage();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Retention cleanup complete! $count records pruned.')),
                          );
                        }
                      },
                      child: const Text('Clean Now'),
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever_outlined,
                        color: AppTheme.alertRed),
                    title: const Text('Wipe All Local Usage Data'),
                    subtitle: const Text('Permanently erase all local usage records and reflections.'),
                    trailing: TextButton(
                      onPressed: () async {
                        await ref.read(localUsageStoreProvider).wipeAllLocalData();
                        await ref.read(localReflectionRepositoryProvider).clearAllReflections();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All local usage data wiped successfully.')),
                          );
                        }
                      },
                      child: const Text('Wipe Data', style: TextStyle(color: AppTheme.alertRed)),
                    ),
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
