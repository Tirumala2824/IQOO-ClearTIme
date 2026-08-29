import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildDashboardScreen extends ConsumerWidget {
  const ChildDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childState = ref.watch(childDashboardControllerProvider);
    final profile = childState.profile;
    final family = childState.family;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: Text('Hey, ${profile?.nickname ?? "Explorer"}! 👋'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Positive Points Hero Card
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
                    color:
                        AppTheme.childPrimary.withAlpha((0.25 * 255).round()),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha((0.2 * 255).round()),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          family != null
                              ? '🏡 ${family.name}'
                              : '🏡 My Family Space',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: AppTheme.childAccent, size: 22),
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
                  const Text(
                    'Mindful Hero Level 1',
                    style: TextStyle(
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
                          : childState.completedMissionsCount /
                              childState.missions.length,
                      backgroundColor:
                          Colors.white.withAlpha((0.3 * 255).round()),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.childAccent),
                      minHeight: 10,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
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

            ...childState.missions.take(2).map((mission) {
              final isDone = mission['isCompleted'] as bool;
              return Card(
                child: ListTile(
                  leading: IconButton(
                    icon: Icon(
                      isDone
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isDone
                          ? AppTheme.childSecondary
                          : AppTheme.neutralMuted,
                      size: 28,
                    ),
                    onPressed: () {
                      ref
                          .read(childDashboardControllerProvider.notifier)
                          .toggleMission(mission['id'] as String);
                    },
                  ),
                  title: Text(
                    mission['title'] as String,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: Text(mission['description'] as String),
                  trailing: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          AppTheme.childAccent.withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${mission["points"]} XP',
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
            Text(
              'Your Mindful Habits',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.childTextDark,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildHabitCard(
                    icon: Icons.wb_sunny_rounded,
                    title: 'Outdoor Time',
                    subtitle: 'Balanced play',
                    color: AppTheme.childAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildHabitCard(
                    icon: Icons.nightlight_round,
                    title: 'Sweet Dreams',
                    subtitle: 'Gentle rest',
                    color: AppTheme.childPrimary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            // Privacy Assurance
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: const [
                    Icon(Icons.lock_rounded,
                        color: AppTheme.childSecondary, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'ClearTime is your personal companion. Your private chats, browsing, and media remain strictly yours.',
                        style: TextStyle(
                            fontSize: 12.5, color: AppTheme.neutralMuted),
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

  Widget _buildHabitCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(color: AppTheme.neutralMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
