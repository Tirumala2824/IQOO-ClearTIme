import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/reflection_model.dart';
import '../controllers/child_dashboard_controller.dart';
import 'child_reflection_dialog.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() => _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-load dashboard data on first mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childState = ref.read(childDashboardControllerProvider);
      final userId = childState.profile?.userId ?? '';
      ref.read(childDashboardControllerProvider.notifier).loadDashboard(userId);
    });
  }

  String _getHeroLevel(int totalXp) {
    if (totalXp >= 500) return 'Mindful Hero Level 5 🌟';
    if (totalXp >= 300) return 'Mindful Hero Level 4 ⭐';
    if (totalXp >= 150) return 'Mindful Hero Level 3 💫';
    if (totalXp >= 50) return 'Mindful Hero Level 2 ✨';
    return 'Mindful Hero Level 1 🌱';
  }

  String _getFocusSubtitle(int focusMinutes) {
    if (focusMinutes >= 120) return 'Amazing focus today!';
    if (focusMinutes >= 60) return 'Great learning!';
    if (focusMinutes >= 30) return 'Good progress!';
    if (focusMinutes > 0) return 'Keep going!';
    return 'Start focusing!';
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(childDashboardControllerProvider);
    final profile = childState.profile;
    final family = childState.family;
    final usage = childState.usageSummary;
    final reflection = childState.todayReflection;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: Text('Hey, ${profile?.nickname ?? "Explorer"}! 👋'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref
                  .read(childDashboardControllerProvider.notifier)
                  .loadDashboard(profile?.userId ?? '');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Usage Permission Warning Card (if native permission not granted)
            if (!childState.hasPermission)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withAlpha((0.15 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.warningOrange.withAlpha((0.5 * 255).round())),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security_update_warning_rounded, color: AppTheme.warningOrange),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Enable Usage Access to track your focus quests locally.',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warningOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      onPressed: () {
                        ref.read(childDashboardControllerProvider.notifier).requestUsagePermission();
                      },
                      child: const Text('Enable', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

            // Hero Points Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.childPrimary, AppTheme.childSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.childPrimary.withAlpha((0.25 * 255).round()),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          family != null ? '🏡 ${family.name}' : '🏡 My Family Space',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppTheme.childAccent, size: 22),
                          const SizedBox(width: 4),
                          Text(
                            '${childState.totalPoints} XP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _getHeroLevel(childState.totalPoints),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${childState.completedMissionsCount} of ${childState.missions.length} daily wellbeing missions completed',
                    style: TextStyle(
                      color: Colors.white.withAlpha((0.9 * 255).round()),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: childState.missions.isEmpty
                          ? 0
                          : childState.completedMissionsCount / childState.missions.length,
                      backgroundColor: Colors.white.withAlpha((0.3 * 255).round()),
                      valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.childAccent),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Local Usage & Focus Metrics Row
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.timer_rounded,
                    title: 'Total Screen',
                    value: usage.formattedTotalTime,
                    subtitle: usage.changePercentageFromYesterday < 0
                        ? '${usage.changePercentageFromYesterday}% vs yest'
                        : 'Balanced',
                    color: AppTheme.childPrimary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.bolt_rounded,
                    title: 'Focus Time',
                    value: usage.formattedFocusTime,
                    subtitle: _getFocusSubtitle(usage.focusMinutes),
                    color: AppTheme.childSecondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildMetricTile(
                    icon: Icons.self_improvement_rounded,
                    title: 'Mindful Breaks',
                    value: '${usage.breakCount}',
                    subtitle: 'Pauses taken',
                    color: AppTheme.warningOrange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Category Breakdown Card
            if (usage.categories.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.neutralBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'App Activity Breakdown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.childTextDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...usage.categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cat.category,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  '${cat.totalMinutes}m (${cat.percentage.toStringAsFixed(0)}%)',
                                  style: const TextStyle(
                                    color: AppTheme.neutralMuted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: (cat.percentage / 100).clamp(0.0, 1.0),
                                backgroundColor: AppTheme.neutralBg,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _getCategoryColor(cat.category),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Daily Reflection Prompt / Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.neutralBorder),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.childSecondary.withAlpha((0.15 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      reflection?.mood.emoji ?? '🌟',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reflection != null
                              ? 'Today felt ${reflection.mood.label}!'
                              : 'How did your screen time feel today?',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          reflection?.notes ?? 'Tap to record your daily mindful check-in.',
                          style: const TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => ChildReflectionDialog(
                          existingReflection: reflection,
                          onSave: (data) {
                            ref
                                .read(childDashboardControllerProvider.notifier)
                                .saveReflection(mood: data.mood, notes: data.notes);
                          },
                          onDelete: () {
                            ref
                                .read(childDashboardControllerProvider.notifier)
                                .deleteTodayReflection();
                          },
                        ),
                      );
                    },
                    child: Text(reflection != null ? 'Edit' : 'Reflect'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Missions Header & List
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Today’s Wellbeing Quests',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.childTextDark,
                      ),
                ),
                TextButton(
                  onPressed: () => context.go(AppRoutes.childMissions),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            ...childState.missions.take(3).map((mission) {
              final isDone = mission.isCompleted;
              return Card(
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isDone ? AppTheme.childSecondary : AppTheme.neutralMuted,
                      size: 28,
                    ),
                    onPressed: () {
                      ref
                          .read(childDashboardControllerProvider.notifier)
                          .toggleMission(mission.id);
                    },
                  ),
                  title: Text(
                    mission.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(mission.description),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.childAccent.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${mission.points} XP',
                      style: const TextStyle(
                        color: AppTheme.warningOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 24),

            // Privacy Guarantee
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: const [
                    Icon(Icons.lock_rounded, color: AppTheme.childSecondary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '100% On-Device Privacy: Your raw app usage, chats, and reflections NEVER leave your phone.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.neutralMuted),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: AppTheme.childTextDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: AppTheme.neutralMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('learn') || lower.contains('educat')) {
      return AppTheme.childPrimary;
    } else if (lower.contains('creativ') || lower.contains('art')) {
      return AppTheme.childSecondary;
    } else if (lower.contains('game') || lower.contains('play')) {
      return AppTheme.childAccent;
    }
    return AppTheme.neutralMuted;
  }
}
