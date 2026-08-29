import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/achievement_model.dart';
import '../controllers/child_achievements_controller.dart';
import '../controllers/child_missions_controller.dart';

import '../controllers/child_dashboard_controller.dart';

class ChildProgressScreen extends ConsumerStatefulWidget {
  const ChildProgressScreen({super.key});

  @override
  ConsumerState<ChildProgressScreen> createState() => _ChildProgressScreenState();
}

class _ChildProgressScreenState extends ConsumerState<ChildProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final usage = ref.read(childDashboardControllerProvider).usageSummary;
      ref.read(childAchievementsControllerProvider.notifier).evaluateAgainstAnalytics(
        focusMinutes: usage.focusMinutes,
        breakCount: usage.breakCount,
        consecutiveDaysGoalMet: 3,
        maxSingleFocusSession: usage.focusMinutes > 30 ? 30 : usage.focusMinutes,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final achState = ref.watch(childAchievementsControllerProvider);
    final missionsState = ref.watch(childMissionsControllerProvider);

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
                  '${missionsState.totalPoints} Total XP',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.childTextDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${achState.unlockedCount} of ${achState.achievements.length} Badges Unlocked',
                  style: const TextStyle(
                      color: AppTheme.neutralMuted, fontSize: 13),
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

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: achState.achievements.length,
            itemBuilder: (context, index) {
              final ach = achState.achievements[index];
              return _buildAchievementCard(ach);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(ChildAchievement ach) {
    final isUnlocked = ach.isUnlocked;
    final color = isUnlocked ? AppTheme.childSecondary : AppTheme.neutralMuted;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? AppTheme.childSecondary.withAlpha((0.5 * 255).round())
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
              color: color.withAlpha((0.15 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getIconData(ach.icon),
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ach.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: isUnlocked ? AppTheme.childTextDark : AppTheme.neutralMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ach.description,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10.5, color: AppTheme.neutralMuted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ach.progress,
              backgroundColor: AppTheme.neutralBg,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'bolt_rounded':
        return Icons.bolt_rounded;
      case 'self_improvement_rounded':
        return Icons.self_improvement_rounded;
      case 'psychology_rounded':
        return Icons.psychology_rounded;
      case 'calendar_month_rounded':
        return Icons.calendar_month_rounded;
      case 'military_tech_rounded':
        return Icons.military_tech_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}
