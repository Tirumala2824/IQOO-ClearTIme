import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/providers/providers.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
        children: [
          // Profile Card
          AppCard(
            child: Row(
              children: [
                AppAvatar(
                  name: user?.displayName ?? 'P',
                  radius: 28,
                  isChild: false,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'Parent Account',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppColors.parentTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.phoneNumber ?? user?.email ?? 'Authenticated Admin',
                        style: const TextStyle(
                          color: AppColors.neutralMuted,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.parentPrimary.withAlpha((0.12 * 255).round()),
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          family?.name ?? 'Family Hub',
                          style: const TextStyle(
                            color: AppColors.parentPrimary,
                            fontWeight: FontWeight.w700,
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

          const SizedBox(height: 16),
          const Text(
            'Family Space & Hub Management',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.parentTextDark,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.parentPrimary.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.hub_rounded,
                        color: AppColors.parentPrimary, size: 22),
                  ),
                  title: Text(
                    family?.name ?? 'Active Family Space',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  subtitle: Text(
                    '${parentState.children.length} linked children · ${parentState.allFamilies.length} family spaces',
                    style: const TextStyle(color: AppColors.neutralMuted, fontSize: 12),
                  ),
                  trailing: const Icon(Icons.edit_rounded,
                      size: 18, color: AppColors.parentPrimary),
                  onTap: () {
                    if (family == null || user == null) return;
                    _showRenameDialog(context, ref, family, user.id);
                  },
                ),
                if (family != null) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.alertRed.withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.delete_forever_rounded,
                          color: AppColors.alertRed, size: 22),
                    ),
                    title: const Text(
                      'Delete Family Space',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppColors.alertRed),
                    ),
                    subtitle: const Text(
                      'Permanently remove this family space and all linked missions/reports',
                      style: TextStyle(color: AppColors.neutralMuted, fontSize: 12),
                    ),
                    onTap: () {
                      if (user == null) return;
                      _showDeleteFamilyDialog(context, ref, family, user.id);
                    },
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Smart Features & Configurations',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.parentTextDark,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.parentPrimary.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: AppColors.parentPrimary, size: 22),
                  ),
                  title: const Text('Downtime & Triggers',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Configure mindful break reminders and schedule limits',
                      style: TextStyle(color: AppColors.neutralMuted, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.neutralMuted),
                  onTap: () => context.push(AppRoutes.parentTriggers),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.parentSecondary.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.psychology_rounded,
                        color: AppColors.parentSecondary, size: 22),
                  ),
                  title: const Text('Local AI Engine & Control Center',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Manage on-device models, prompt templates & diagnostics',
                      style: TextStyle(color: AppColors.neutralMuted, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.neutralMuted),
                  onTap: () => context.push(AppRoutes.localAiSettings),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.infoBlue.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.compare_arrows_rounded,
                        color: AppColors.infoBlue, size: 22),
                  ),
                  title: const Text('Report Comparison',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Compare multiple periods or children side-by-side',
                      style: TextStyle(color: AppColors.neutralMuted, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.neutralMuted),
                  onTap: () => context.push(AppRoutes.parentReportCompare),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          const Text(
            'Notification Preferences',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.parentTextDark,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Daily Morning Summary', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  subtitle: const Text('Gentle overview of yesterday’s family screen balance', style: TextStyle(fontSize: 12)),
                  value: notifs.dailySummary,
                  activeThumbColor: AppColors.parentPrimary,
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
                  title: const Text('Instant Activity & Limit Alerts', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  subtitle: const Text('Get notified when child completes an offline activity', style: TextStyle(fontSize: 12)),
                  value: notifs.instantAlerts,
                  activeThumbColor: AppColors.parentPrimary,
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

          const SizedBox(height: 16),
          const Text(
            'Privacy & Local Data Management',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14.5,
              color: AppColors.parentTextDark,
            ),
          ),
          const SizedBox(height: 8),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.successGreen.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(Icons.privacy_tip_rounded,
                        color: AppColors.successGreen, size: 22),
                  ),
                  title: const Text('Privacy Center',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: const Text('Full transparency on local-only processing & data controls',
                      style: TextStyle(color: AppColors.neutralMuted, fontSize: 12)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: AppColors.neutralMuted),
                  onTap: () => context.push(AppRoutes.parentPrivacyCenter),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: const Text('Local On-Device Processing Only', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  subtitle: const Text('Ensures raw screen telemetry stays on device hardware', style: TextStyle(fontSize: 12)),
                  value: privacy.localProcessingOnly,
                  activeThumbColor: AppColors.parentPrimary,
                  onChanged: (val) {
                    ref
                        .read(parentDashboardControllerProvider.notifier)
                        .savePrivacySettings(
                          privacy.copyWith(localProcessingOnly: val),
                        );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Clear Local Parent Chat History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: const Text('Purge all on-device conversation records for this device', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.delete_sweep_rounded, color: AppColors.errorRed),
                  onTap: () async {
                    final convoRepo = ref.read(parentConversationRepositoryProvider);
                    final children = parentState.children;
                    for (final c in children) {
                      await convoRepo.deleteAllConversations(c.id);
                    }
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Local parent chat history cleared completely.'),
                          backgroundColor: AppColors.parentPrimary,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          AppButton(
            label: 'Sign Out',
            icon: Icons.logout_rounded,
            variant: AppButtonVariant.outlined,
            customColor: AppColors.errorRed,
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, dynamic family, String userId) {
    final controller = TextEditingController(text: family.name as String);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: AppColors.parentPrimary),
            SizedBox(width: 8),
            Flexible(child: Text('Rename Family Space', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'New Family Name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.parentPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                final success = await ref
                    .read(parentDashboardControllerProvider.notifier)
                    .renameFamily(family.id as String, name, userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success ? 'Family renamed to "$name"' : 'Failed to rename family.'),
                      backgroundColor: success ? AppColors.successGreen : AppColors.alertRed,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteFamilyDialog(BuildContext context, WidgetRef ref, dynamic family, String userId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.alertRed),
            SizedBox(width: 8),
            Flexible(child: Text('Delete Family Space', style: TextStyle(fontWeight: FontWeight.w700))),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${family.name}"? All associated missions, reports, triggers, and child profiles in this space will be deleted permanently. This action cannot be undone.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(parentDashboardControllerProvider.notifier)
                  .deleteCurrentFamily(family.id as String, userId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Family "${family.name}" has been permanently deleted.'
                          : 'Failed to delete family.',
                    ),
                    backgroundColor: success ? AppColors.successGreen : AppColors.alertRed,
                  ),
                );
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}
