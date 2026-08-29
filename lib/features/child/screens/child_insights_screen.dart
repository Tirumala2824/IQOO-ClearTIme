import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../controllers/child_dashboard_controller.dart';

class ChildInsightsScreen extends ConsumerWidget {
  const ChildInsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childState = ref.watch(childDashboardControllerProvider);
    final usage = childState.usageSummary;
    final focusMin = usage.focusMinutes;
    final totalMin = usage.totalMinutes;
    final breaks = usage.breakCount;
    final topCategory = usage.categories.isNotEmpty
        ? usage.categories.first.category
        : 'Learning';

    // Generate dynamic insights based on actual usage
    final insights = _generateDynamicInsights(
      focusMinutes: focusMin,
      totalMinutes: totalMin,
      breakCount: breaks,
      topCategory: topCategory,
      changePercent: usage.changePercentageFromYesterday,
    );

    // Dynamic tip of the day based on hour
    final tipOfDay = _getTipOfDay();

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('Wellbeing Insights 💡'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Dynamic Stats Summary
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.childPrimary, AppTheme.childSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s Snapshot',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSnapshotStat(
                      '${totalMin}m',
                      'Screen Time',
                      Icons.timer_rounded,
                    ),
                    _buildSnapshotStat(
                      '${focusMin}m',
                      'Focus',
                      Icons.bolt_rounded,
                    ),
                    _buildSnapshotStat(
                      '$breaks',
                      'Breaks',
                      Icons.self_improvement_rounded,
                    ),
                    _buildSnapshotStat(
                      '${(focusMin / (totalMin > 0 ? totalMin : 1) * 100).round()}%',
                      'Focus Rate',
                      Icons.insights_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Dynamic Tip
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emoji_objects_rounded,
                        color: AppTheme.childAccent, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Tip of the Day',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  tipOfDay,
                  style: const TextStyle(
                      color: AppTheme.childTextDark, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Your Insights',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.childTextDark,
                ),
          ),
          const SizedBox(height: 12),

          ...insights.map((insight) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildInsightCard(
                  icon: insight.icon,
                  title: insight.title,
                  description: insight.description,
                  badge: insight.badge,
                  color: insight.color,
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildSnapshotStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
      ],
    );
  }

  String _getTipOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 10) {
      return '🌅 Morning is the best time for focused learning! Your brain is fresh and ready to absorb new information. Try a 20-minute study sprint before play time.';
    } else if (hour < 14) {
      return '☀️ The 20-20-20 Rule: Every 20 minutes spent looking at a screen, look at something 20 feet away for 20 seconds. It gives your eyes a super recharge!';
    } else if (hour < 18) {
      return '🎯 Afternoon energy tip: Take a 5-minute movement break! Jump, stretch, or do a silly dance. You\'ll come back to your tasks feeling refreshed.';
    } else {
      return '🌙 Evening wind-down: Putting your phone away 30 minutes before sleep helps you wake up refreshed and recharged for tomorrow\'s adventures!';
    }
  }

  List<_InsightItem> _generateDynamicInsights({
    required int focusMinutes,
    required int totalMinutes,
    required int breakCount,
    required String topCategory,
    required double changePercent,
  }) {
    final insights = <_InsightItem>[];

    // Focus ratio insight
    final focusRatio = totalMinutes > 0 ? focusMinutes / totalMinutes : 0.0;
    if (focusRatio > 0.5) {
      insights.add(_InsightItem(
        icon: Icons.menu_book_rounded,
        title: 'Focus Champion!',
        description:
            'You\'ve spent ${(focusRatio * 100).round()}% of your screen time on focused activities today. That\'s excellent balance!',
        badge: 'Top Habit',
        color: AppTheme.childSecondary,
      ));
    } else if (focusRatio > 0.3) {
      insights.add(_InsightItem(
        icon: Icons.menu_book_rounded,
        title: 'Building Focus Habits',
        description:
            '${(focusRatio * 100).round()}% focus time today. Try grouping study sessions together to boost this to 50%+!',
        badge: 'Improving',
        color: AppTheme.childPrimary,
      ));
    } else {
      insights.add(_InsightItem(
        icon: Icons.menu_book_rounded,
        title: 'Focus Time Opportunity',
        description:
            'Your focus ratio is ${(focusRatio * 100).round()}% today. Try a quick 15-minute learning sprint to boost it!',
        badge: 'Try This',
        color: AppTheme.warningOrange,
      ));
    }

    // Break insight
    if (breakCount >= 5) {
      insights.add(_InsightItem(
        icon: Icons.timer_outlined,
        title: 'Break Master! 🧘',
        description:
            'Amazing! You\'ve taken $breakCount mindful breaks today. Your eyes and brain thank you!',
        badge: 'Achieved',
        color: AppTheme.successGreen,
      ));
    } else if (breakCount > 0) {
      insights.add(_InsightItem(
        icon: Icons.timer_outlined,
        title: 'Mindful Breaks',
        description:
            'You\'ve taken $breakCount break${breakCount > 1 ? "s" : ""} so far. Aim for 5 daily breaks to keep your brain sharp!',
        badge: '${5 - breakCount} more to go',
        color: AppTheme.childSecondary,
      ));
    } else {
      insights.add(_InsightItem(
        icon: Icons.timer_outlined,
        title: 'Time for a Break!',
        description:
            'No breaks taken yet today. Take a quick stretch or look out the window for 20 seconds!',
        badge: 'Start Now',
        color: AppTheme.warningOrange,
      ));
    }

    // Usage trend insight
    if (changePercent < -10) {
      insights.add(_InsightItem(
        icon: Icons.trending_down_rounded,
        title: 'Great Screen Balance',
        description:
            'Your screen time is ${changePercent.abs().toStringAsFixed(0)}% less than yesterday. You\'re building healthy habits!',
        badge: 'Trending Down',
        color: AppTheme.successGreen,
      ));
    } else if (changePercent > 15) {
      insights.add(_InsightItem(
        icon: Icons.trending_up_rounded,
        title: 'Screen Time Alert',
        description:
            'Your usage is ${changePercent.toStringAsFixed(0)}% higher than yesterday. Consider taking a longer outdoor break.',
        badge: 'Check In',
        color: AppTheme.warningOrange,
      ));
    }

    // Top category insight
    insights.add(_InsightItem(
      icon: Icons.category_rounded,
      title: 'Top Activity: $topCategory',
      description:
          'Your most-used category today is $topCategory. Variety is key — try exploring a different app category!',
      badge: 'Activity Mix',
      color: AppTheme.childPrimary,
    ));

    return insights;
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String description,
    required String badge,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                  color: AppTheme.neutralMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightItem {
  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final Color color;

  const _InsightItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.color,
  });
}
