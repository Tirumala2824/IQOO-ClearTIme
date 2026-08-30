import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_card.dart';
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
      backgroundColor: AppColors.childSurface,
      appBar: AppBar(
        backgroundColor: AppColors.childSurface,
        title: const Text(
          'My Progress & Badges',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.childTextDark,
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
            // 1. Stats Summary Hero Card
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.childPrimary, AppColors.childSecondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.childPrimary.withAlpha((0.25 * 255).round()),
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
                      const Icon(Icons.task_alt_rounded,
                          color: AppColors.childAccent, size: 32),
                      const SizedBox(height: 4),
                      Text(
                        '${missionsState.completedCount}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        'Activities Done',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                  ),
                  Column(
                    children: [
                      const Icon(Icons.local_fire_department_rounded,
                          color: AppColors.warningOrange, size: 32),
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
                        'Active Streak',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: Colors.white.withAlpha((0.3 * 255).round()),
                  ),
                  Column(
                    children: [
                      const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 32),
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
                        'Goals Reached',
                        style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // 2. Real 7-Day Activity Trend
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '7-Day Activity Trend',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.childTextDark,
                        ),
                      ),
                      Row(
                        children: [
                          _buildLegendDot(AppColors.childSecondary, 'Focus'),
                          const SizedBox(width: 10),
                          _buildLegendDot(AppColors.childPrimary, 'Screen'),
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
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2.5)),
                        );
                      }
                      final dailyList = snapshot.data ?? [];
                      final totalWeekMinutes = dailyList.fold<int>(
                          0, (sum, d) => sum + d.totalMinutes);

                      if (dailyList.isEmpty || totalWeekMinutes == 0) {
                        return const SizedBox(
                          height: 90,
                          child: Center(
                            child: Text(
                              'No activity recorded yet across this week.\nYour daily trend will appear here as you use your device!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.neutralMuted,
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

            const SizedBox(height: 18),

            // 3. Wellbeing Badges
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Wellbeing Badges 🏆',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.childTextDark,
                  ),
                ),
                Text(
                  '${achState.unlockedCount} of ${achState.achievements.length} unlocked',
                  style: const TextStyle(
                    color: AppColors.neutralMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

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
                    style: TextStyle(color: AppColors.neutralMuted),
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
                  childAspectRatio: 0.9,
                ),
                itemCount: achState.achievements.length,
                itemBuilder: (context, index) {
                  final ach = achState.achievements[index];
                  return _buildAchievementCard(ach);
                },
              ),
            const SizedBox(height: 24),
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
          style: const TextStyle(fontSize: 11, color: AppColors.neutralMuted, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDynamic7DayChart(List<DailyUsage> dailyList) {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
                      color: AppColors.childPrimary.withAlpha((0.35 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Container(
                    width: 10,
                    height: focusHeight,
                    decoration: BoxDecoration(
                      color: AppColors.childSecondary,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                dayLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.neutralMuted,
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

    return AppCard(
      padding: const EdgeInsets.all(12),
      borderColor: isUnlocked
          ? AppColors.childAccent.withAlpha((0.6 * 255).round())
          : AppColors.neutralBorder,
      borderWidth: isUnlocked ? 1.5 : 1.0,
      backgroundColor: isUnlocked ? Colors.white : AppColors.neutral50,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppColors.childAccent.withAlpha((0.15 * 255).round())
                  : AppColors.neutral200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUnlocked
                  ? Icons.emoji_events_rounded
                  : Icons.lock_outline_rounded,
              color: isUnlocked ? AppColors.childAccent : AppColors.neutralMuted,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            ach.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isUnlocked ? AppColors.childTextDark : AppColors.neutralMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            ach.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.neutralMuted,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppColors.childSecondary.withAlpha((0.15 * 255).round())
                  : AppColors.neutral200,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              isUnlocked ? 'Unlocked ✓' : 'Locked',
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isUnlocked
                    ? AppColors.childSecondary
                    : AppColors.neutralMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
