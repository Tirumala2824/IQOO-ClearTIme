import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildProgressScreen extends ConsumerWidget {
  const ChildProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childState = ref.watch(childDashboardControllerProvider);

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('My Wellbeing Badges 🏆'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // XP Progress Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Column(
              children: [
                const Icon(Icons.military_tech_rounded,
                    color: AppTheme.childAccent, size: 48),
                const SizedBox(height: 8),
                Text(
                  '${childState.totalPoints} Total XP',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.childTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Keep completing mindful quests to reach Level 2!',
                  style: TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Achievements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.childTextDark,
                ),
          ),
          const SizedBox(height: 12),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildBadgeItem(
                icon: Icons.wb_sunny_rounded,
                title: 'Sunlight Explorer',
                subtitle: 'Outdoor play master',
                isUnlocked: true,
                color: AppTheme.childAccent,
              ),
              _buildBadgeItem(
                icon: Icons.bolt_rounded,
                title: 'Focus Champion',
                subtitle: 'Undistracted sessions',
                isUnlocked: true,
                color: AppTheme.childPrimary,
              ),
              _buildBadgeItem(
                icon: Icons.bedtime_rounded,
                title: 'Rest Master',
                subtitle: '3-day evening pause',
                isUnlocked: false,
                color: AppTheme.neutralMuted,
              ),
              _buildBadgeItem(
                icon: Icons.family_restroom_rounded,
                title: 'Family Champion',
                subtitle: 'Screen-free dinners',
                isUnlocked: false,
                color: AppTheme.neutralMuted,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isUnlocked,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? color.withAlpha((0.5 * 255).round())
              : AppTheme.neutralBorder,
          width: isUnlocked ? 1.5 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isUnlocked ? color : AppTheme.neutralMuted)
                  .withAlpha((0.15 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isUnlocked ? color : AppTheme.neutralMuted,
              size: 28,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color:
                  isUnlocked ? AppTheme.childTextDark : AppTheme.neutralMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: AppTheme.neutralMuted),
          ),
        ],
      ),
    );
  }
}
