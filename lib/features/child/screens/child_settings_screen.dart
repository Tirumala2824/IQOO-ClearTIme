import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildSettingsScreen extends ConsumerStatefulWidget {
  const ChildSettingsScreen({super.key});

  @override
  ConsumerState<ChildSettingsScreen> createState() =>
      _ChildSettingsScreenState();
}

class _ChildSettingsScreenState extends ConsumerState<ChildSettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(childDashboardControllerProvider);
    final profile = childState.profile;
    final family = childState.family;
    final childName = profile?.nickname ?? 'Explorer';

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
          // ─── 1. PROFILE CARD ───
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
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      AppTheme.childPrimary.withAlpha((0.15 * 255).round()),
                  child: const Text('🌟', style: TextStyle(fontSize: 32)),
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
                            : '🏡 My Family Space',
                        style: const TextStyle(
                          color: AppTheme.neutralMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── 2. PRIVACY & SAFETY PROMISE ───
          const Text(
            'Your Privacy Promise 🛡️',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.childTextDark,
            ),
          ),
          const SizedBox(height: 8),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.childSecondary.withAlpha((0.3 * 255).round()),
              ),
            ),
            child: Column(
              children: [
                _buildPrivacyRow(
                  icon: Icons.smartphone_rounded,
                  title: '100% On Your Device',
                  description:
                      'Your app names, screen time numbers, and reflections stay on this phone.',
                ),
                const Divider(height: 24),
                _buildPrivacyRow(
                  icon: Icons.smart_toy_rounded,
                  title: 'Private AI Coach',
                  description:
                      'Your AI Buddy thinks right on your phone without sending chats to the internet.',
                ),
                const Divider(height: 24),
                _buildPrivacyRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Private Reflections',
                  description:
                      'How you feel and your daily notes are private to you.',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── 3. PREFERENCES ───
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
                    'Friendly reminders to take eye breaks and celebrate completed goals.',
                    style: TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
                  ),
                  value: _notificationsEnabled,
                  activeThumbColor: AppTheme.childSecondary,
                  onChanged: (val) {
                    setState(() {
                      _notificationsEnabled = val;
                    });
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── 4. SIGN OUT BUTTON ───
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

  Widget _buildPrivacyRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.childSecondary.withAlpha((0.15 * 255).round()),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppTheme.childSecondary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.childTextDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.neutralMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
