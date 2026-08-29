import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../data/models/privacy_setting_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentSettingsScreen extends ConsumerWidget {
  const ParentSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final parentState = ref.watch(parentDashboardControllerProvider);
    final user = authState.user;
    final family = parentState.family;
    final notifs = parentState.notificationPrefs ??
        NotificationPreference(
          id: '',
          userId: user?.id ?? '',
          familyId: family?.id ?? '',
          updatedAt: DateTime.now(),
        );
    final privacy = parentState.privacySettings ??
        PrivacySetting(
          id: '',
          familyId: family?.id ?? '',
          userId: user?.id ?? '',
          updatedAt: DateTime.now(),
        );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family & App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Profile Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.parentPrimary,
                    child: Text(
                      user?.displayName?.substring(0, 1).toUpperCase() ?? 'P',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Parent Account',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.phoneNumber ??
                              user?.email ??
                              'Authenticated Admin',
                          style: const TextStyle(
                              color: AppTheme.neutralMuted, fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.parentPrimary
                                .withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            family?.name ?? 'Family Hub',
                            style: const TextStyle(
                              color: AppTheme.parentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Local AI Engine & Control Center',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.parentSecondary.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: AppTheme.parentSecondary, size: 24),
              ),
              title: const Text(
                'Local AI Control Center',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              subtitle: const Text(
                'Manage on-device models, prompt templates & offline diagnostics',
                style: TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppTheme.neutralMuted),
              onTap: () => context.push(AppRoutes.localAiSettings),
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Notification Preferences',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Daily Morning Summary'),
                  subtitle: const Text(
                      'Gentle overview of yesterday’s family balance'),
                  value: notifs.dailySummary,
                  activeThumbColor: AppTheme.parentPrimary,
                  onChanged: (val) {
                    ref
                        .read(parentDashboardControllerProvider.notifier)
                        .saveNotificationPreferences(
                          notifs.copyWith(dailySummary: val),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Instant Limit Alerts'),
                  subtitle: const Text(
                      'Receive notifications when downtime triggers trigger'),
                  value: notifs.instantAlerts,
                  activeThumbColor: AppTheme.parentPrimary,
                  onChanged: (val) {
                    ref
                        .read(parentDashboardControllerProvider.notifier)
                        .saveNotificationPreferences(
                          notifs.copyWith(instantAlerts: val),
                        );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text(
            'Privacy & Data Minimization',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Local On-Device Processing Only'),
                  subtitle: const Text(
                      'Ensures raw device telemetry never leaves device hardware'),
                  value: privacy.localProcessingOnly,
                  activeThumbColor: AppTheme.parentPrimary,
                  onChanged: (val) {
                    ref
                        .read(parentDashboardControllerProvider.notifier)
                        .savePrivacySettings(
                          privacy.copyWith(localProcessingOnly: val),
                        );
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Anonymize Aggregated Summaries'),
                  subtitle: const Text(
                      'Removes hardware identifiers from family reports'),
                  value: privacy.anonymizeData,
                  activeThumbColor: AppTheme.parentPrimary,
                  onChanged: (val) {
                    ref
                        .read(parentDashboardControllerProvider.notifier)
                        .savePrivacySettings(
                          privacy.copyWith(anonymizeData: val),
                        );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Data Retention Horizon'),
                  subtitle: Text(
                      '${privacy.dataRetentionDays} days (auto-pruned locally)'),
                  trailing: const Icon(Icons.history_toggle_off_rounded),
                ),
              ],
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
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
