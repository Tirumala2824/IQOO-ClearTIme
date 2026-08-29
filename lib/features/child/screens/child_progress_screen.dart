import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/models/usage_models.dart';
import '../controllers/child_achievements_controller.dart';
import '../controllers/child_missions_controller.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildProgressScreen extends ConsumerStatefulWidget {
  const ChildProgressScreen({super.key});

  @override
  ConsumerState<ChildProgressScreen> createState() =>
      _ChildProgressScreenState();
}

class _ChildProgressScreenState extends ConsumerState<ChildProgressScreen> {
  Future<List<DailyUsage>>? _weeklyUsageFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _weeklyUsageFuture = ref.read(usageDataProvider).getDailyUsage();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childState = ref.read(childDashboardControllerProvider);
      final usage = childState.usageSummary;
      final history = childState.coachingHistory;

      ref
          .read(childAchievementsControllerProvider.notifier)
          .evaluateAgainstAnalytics(
            focusMinutes: usage.focusMinutes,
            breakCount: usage.breakCount,
            consecutiveDaysGoalMet: history.streakDays,
            maxSingleFocusSession: usage.focusMinutes,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final achState = ref.watch(childAchievementsControllerProvider);
    final missionsState = ref.watch(childMissionsControllerProvider);
    final childState = ref.watch(childDashboardControllerProvider);
    final history = childState.coachingHistory;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        elevation: 0,
        title: const Text(
          'My Progress & Badges 🏆',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppTheme.childTextDark,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadData();
          });
          await ref.read(childAchievementsControllerProvider.notifier).loadAchievements();
        },
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          children: [
            // ─── 1. REAL STATS SUMMARY ───
            Container(
              padding: const EdgeInsets.all(22),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Icon(Icons.star_rounded,
                          color: AppTheme.childAccent, size: 34),
                      const SizedBox(height: 4),
                      Text(
                        '${missionsState.totalPoints} XP',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Quests XP',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 46,
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                  ),
                  Column(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppTheme.warningOrange, size: 34),
                      const SizedBox(height: 4),
                      Text(
                        '${history.streakDays} ${history.streakDays == 1 ? "Day" : "Days"}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Coaching Streak',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 46,
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                  ),
                  Column(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 34),
                      const SizedBox(height: 4),
                      Text(
                        '${history.goalsCompleted}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Goals Done',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 2. REAL 7-DAY USAGE TREND ───
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.neutralBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((0.02 * 255).round()),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '7-Day Activity Trend',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: AppTheme.childTextDark,
                        ),
                      ),
                      Row(
                        children: [
                          _buildLegendDot(AppTheme.childSecondary, 'Focus'),
                          const SizedBox(width: 10),
                          _buildLegendDot(AppTheme.childPrimary, 'Screen'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<List<DailyUsage>>(
                    future: _weeklyUsageFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 110,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final dailyList = snapshot.data ?? [];
                      final totalWeekMinutes = dailyList.fold<int>(
                          0, (sum, d) => sum + d.totalMinutes);

                      if (dailyList.isEmpty || totalWeekMinutes == 0) {
                        return const SizedBox(
                          height: 100,
                          child: Center(
                            child: Text(
                              'No activity recorded yet across this week.\nYour daily trend will appear here as you use your device!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.neutralMuted,
                              ),
                            ),
                          ),
                        );
                      }

                      return _buildDynamic7DayChart(dailyList);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ─── 3. REAL WELLBEING BADGES ───
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Wellbeing Badges',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.childTextDark,
                  ),
                ),
                Text(
                  '${achState.unlockedCount} of ${achState.achievements.length} unlocked',
                  style: const TextStyle(
                    color: AppTheme.neutralMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (achState.isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (achState.achievements.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No badges available yet.',
                    style: TextStyle(color: AppTheme.neutralMuted),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.88,
                ),
                itemCount: achState.achievements.length,
                itemBuilder: (context, index) {
                  final ach = achState.achievements[index];
                  return _buildAchievementCard(ach);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.neutralMuted),
        ),
      ],
    );
  }

  Widget _buildDynamic7DayChart(List<DailyUsage> dailyList) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Find max value to scale chart proportionally
    int maxVal = 60;
    for (final d in dailyList) {
      if (d.totalMinutes > maxVal) maxVal = d.totalMinutes;
    }

    return SizedBox(
      height: 120,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: dailyList.map((d) {
          final dayLabel = dayNames[d.date.weekday - 1];
          final totalHeight = ((d.totalMinutes / maxVal) * 80).clamp(4.0, 80.0);
          final focusHeight = ((d.focusMinutes / maxVal) * 80).clamp(0.0, totalHeight);

          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 10,
                    height: totalHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.childPrimary.withAlpha((0.35 * 255).round()),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 10,
                    height: focusHeight,
                    decoration: BoxDecoration(
                      color: AppTheme.childSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dayLabel,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: AppTheme.neutralMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAchievementCard(ChildAchievement ach) {
    final isUnlocked = ach.isUnlocked;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : AppTheme.neutralBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? AppTheme.childAccent.withAlpha((0.7 * 255).round())
              : AppTheme.neutralBorder,
          width: isUnlocked ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.childAccent.withAlpha((0.15 * 255).round())
                  : Colors.grey.withAlpha((0.1 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              color: isUnlocked ? AppTheme.childAccent : AppTheme.neutralMuted,
              size: 28,
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
          const SizedBox(height: 3),
          Text(
            ach.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10.5,
              color: AppTheme.neutralMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.childSecondary.withAlpha((0.15 * 255).round())
                  : Colors.grey.withAlpha((0.15 * 255).round()),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isUnlocked ? 'Unlocked ✓' : 'Locked',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isUnlocked
                    ? AppTheme.childSecondary
                    : AppTheme.neutralMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
