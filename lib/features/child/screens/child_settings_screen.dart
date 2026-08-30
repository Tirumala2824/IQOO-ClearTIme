import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/abstractions/usage_data_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/llm_models.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../data/models/reflection_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/child_dashboard_controller.dart';

/// My Profile & Privacy — rebuilt from real state.
///
/// Shows the real child/family profile (or a setup state), allows authorized
/// profile edits, persists notification preferences, and displays live
/// privacy capability cards. No fallback names or fabricated data.
class ChildSettingsScreen extends ConsumerStatefulWidget {
  const ChildSettingsScreen({super.key});

  @override
  ConsumerState<ChildSettingsScreen> createState() =>
      _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends ConsumerState<ChildSettingsScreen> {
  NotificationPreference? _notificationPrefs;
  bool _prefsLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationPrefs();
  }

  Future<void> _loadNotificationPrefs() async {
    final profile = ref.read(childDashboardControllerProvider).profile;
    if (profile == null) {
      setState(() => _prefsLoading = false);
      return;
    }
    try {
      final prefs = await ref
          .read(configurationRepositoryProvider)
          .getNotificationPreferences(profile.userId);
      if (mounted) {
        setState(() {
          _notificationPrefs = prefs;
          _prefsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _prefsLoading = false);
    }
  }

  Future<void> _setInstantAlerts(bool enabled) async {
    final profile = ref.read(childDashboardControllerProvider).profile;
    if (profile == null) return;
    final prefs = _notificationPrefs ??
        NotificationPreference(
          id: '',
          userId: profile.userId,
          familyId: profile.familyId,
          updatedAt: DateTime.now(),
        );
    final updated = prefs.copyWith(instantAlerts: enabled);
    try {
      final saved = await ref
          .read(configurationRepositoryProvider)
          .updateNotificationPreferences(updated);
      if (mounted) setState(() => _notificationPrefs = saved);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your notification preference.'),
          ),
        );
      }
    }
  }

  Future<void> _editProfile() async {
    final profile = ref.read(childDashboardControllerProvider).profile;
    if (profile == null) return;

    final nicknameController = TextEditingController(text: profile.nickname);
    final ageController =
        TextEditingController(text: profile.age?.toString() ?? '');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nicknameController,
              decoration: const InputDecoration(labelText: 'Nickname'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (optional)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nickname = nicknameController.text.trim();
              if (nickname.isEmpty) return;
              final age = int.tryParse(ageController.text.trim());
              try {
                final updated = await ref
                    .read(familyRepositoryProvider)
                    .updateChildProfile(
                      nickname: nickname,
                      age: age,
                      avatarIndex: profile.avatarIndex,
                    );
                if (updated != null && ctx.mounted) {
                  Navigator.of(ctx).pop(true);
                }
              } catch (_) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Profile update failed. Please try again.'),
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
    if (result == true && mounted) {
      await ref
          .read(childDashboardControllerProvider.notifier)
          .loadDashboard(profile.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(childDashboardControllerProvider);
    final profile = childState.profile;
    final family = childState.family;
    final childName = profile?.nickname;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        elevation: 0,
        title: const Text(
          'My Profile & Privacy 👤',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppTheme.childTextDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
        children: [
          // ─── 1. PROFILE CARD (real state only) ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppTheme.neutralBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((0.02 * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: profile == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_off_outlined,
                              color: AppTheme.neutralMuted),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Profile setup needed',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: AppTheme.childTextDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Join a family with your parent\'s invitation to '
                        'complete your profile.',
                        style: TextStyle(
                          color: AppTheme.neutralMuted,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 12),
                    ],
                  )
                : Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppTheme.childPrimary
                            .withAlpha((0.15 * 255).round()),
                        child: Text(
                          childName!.isNotEmpty
                              ? childName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 28,
                            color: AppTheme.childPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              childName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                                color: AppTheme.childTextDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              family?.name != null
                                  ? '🏡 Member of ${family!.name}'
                                  : '🏡 Not joined to a family yet',
                              style: const TextStyle(
                                color: AppTheme.neutralMuted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Edit profile',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: _editProfile,
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: 24),

          // ─── 2. PRIVACY CAPABILITY CARDS (live state) ───
          const Text(
            'Your Privacy at a Glance 🛡️',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.childTextDark,
            ),
          ),
          const SizedBox(height: 8),
          _CapabilityCard(
            icon: Icons.smartphone_rounded,
            title: 'Usage access',
            description: _usageAccessDescription(childState),
            ready: childState.hasUsageAccess,
          ),
          _CapabilityCard(
            icon: Icons.lock_outline_rounded,
            title: 'Encrypted local storage',
            description:
                'Goals, reflections, and activity summaries are stored '
                'encrypted on this device only.',
            ready: true,
          ),
          _AiReadinessCard(ref: ref),
          _ReflectionStorageCard(ref: ref),
          _ReportSharingCard(ref: ref),

          const SizedBox(height: 24),

          // ─── 3. PLAIN-LANGUAGE PRIVACY ───
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.childSecondary.withAlpha((0.3 * 255).round()),
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What stays on your device',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Your raw activity (which apps you used), your private '
                  'reflections, and your chats with the wellbeing buddy stay '
                  'on this phone. They are never uploaded to the internet.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
                SizedBox(height: 12),
                Text(
                  'What is shared with your parents',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(height: 8),
                Text(
                  'Only an approved summary report — totals and trends, '
                  'never app names or private notes — is shared with your '
                  'linked parents when a report is generated.',
                  style: TextStyle(fontSize: 12.5, height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── 4. NOTIFICATION PREFERENCES (persisted) ───
          const Text(
            'Preferences ⚙️',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.childTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_active_outlined,
                      color: AppTheme.childSecondary, size: 26),
                  title: const Text(
                    'Gentle Wellbeing Alerts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Friendly reminders to take eye breaks and celebrate completed activities.',
                    style: TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
                  ),
                  value:
                      _notificationPrefs?.instantAlerts ?? true,
                  activeThumbColor: AppTheme.childSecondary,
                  onChanged: _prefsLoading ? null : _setInstantAlerts,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── 5. SIGN OUT BUTTON ───
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
            label: const Text('Sign Out',
                style: TextStyle(
                  color: AppTheme.errorRed,
                  fontWeight: FontWeight.bold,
                )),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: AppTheme.errorRed),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _usageAccessDescription(ChildDashboardState state) {
    switch (state.usageAccessState) {
      case UsageAccessState.ready:
        return 'Reading real activity from this device.';
      case UsageAccessState.permissionNeeded:
        return 'Needed for real activity tracking. Open Setup to grant it.';
      case UsageAccessState.unsupported:
        return 'No authorized activity service exists on this platform.';
      case UsageAccessState.collectionFailed:
        return 'Reading activity failed. Try again from Setup.';
    }
  }
}

class _CapabilityCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool ready;

  const _CapabilityCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 22,
              color: ready ? AppTheme.successGreen : AppTheme.neutralMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(description,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.neutralMuted,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReadinessCard extends ConsumerWidget {
  final WidgetRef ref;

  const _AiReadinessCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final llm = ref.watch(localLlmProvider);
    return FutureBuilder<ModelInfo>(
      future: llm.getModelInfo(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        if (info == null) {
          return const _CapabilityCard(
            icon: Icons.smart_toy_outlined,
            title: 'AI model readiness',
            description: 'Checking…',
            ready: false,
          );
        }
        return _CapabilityCard(
          icon: Icons.smart_toy_outlined,
          title: 'AI model readiness',
          description: info.isInstalled
              ? (info.isLoaded
                  ? 'Local model ready for on-device answers.'
                  : 'Model installed — loading when needed.')
              : 'No model installed. AI features show setup guidance.',
          ready: info.isInstalled && info.isLoaded,
        );
      },
    );
  }
}

class _ReflectionStorageCard extends ConsumerWidget {
  final WidgetRef ref;

  const _ReflectionStorageCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    return FutureBuilder<List<DailyReflection>>(
      future: ref
          .read(localReflectionRepositoryProvider)
          .getReflections(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _CapabilityCard(
          icon: Icons.auto_stories_outlined,
          title: 'Reflection storage',
          description: count > 0
              ? '$count private reflections stored encrypted on this device.'
              : 'No reflections yet. They are stored encrypted, privately.',
          ready: true,
        );
      },
    );
  }
}

class _ReportSharingCard extends ConsumerWidget {
  final WidgetRef ref;

  const _ReportSharingCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final profile = ref.watch(childDashboardControllerProvider).profile;
    return FutureBuilder<List<ApprovedReport>>(
      future: profile == null
          ? Future.value(const [])
          : ref
              .read(approvedReportRepositoryProvider)
              .getApprovedReports(profile.id),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        return _CapabilityCard(
          icon: Icons.summarize_outlined,
          title: 'Report sharing',
          description: count > 0
              ? '$count approved snapshot${count == 1 ? '' : 's'} shared '
                  'with linked parents. Raw activity is never shared.'
              : 'No reports shared yet. Only approved summaries are ever '
                  'shared.',
          ready: true,
        );
      },
    );
  }
}
