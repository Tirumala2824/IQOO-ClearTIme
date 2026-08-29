import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/coaching_models.dart';
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
    final patterns = childState.detectedPatterns;
    final history = childState.coachingHistory;

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
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.childPrimary.withAlpha((0.25 * 255).round()),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
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
                      'Today\'s Snapshot',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha((0.2 * 255).round()),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '🔥 ${history.streakDays}d Streak',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
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

          // ─── DETECTED PATTERNS SECTION ───
          Row(
            children: [
              const Text('🔍', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Detected Habit Patterns',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.childTextDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (patterns.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'No habit anomalies detected today. Keep up your balanced screen routine!',
                  style: TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...patterns.map((p) => _buildPatternCard(p)),

          const SizedBox(height: 20),

          // ─── COACHING TIMELINE / HISTORY ───
          Row(
            children: [
              const Text('📜', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Coaching Loop Timeline',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.childTextDark,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (history.sessions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Coaching history will record daily as you complete goals.',
                  style: TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
                ),
              ),
            )
          else
            ...history.sessions.reversed.take(5).map((s) => _buildSessionTile(s)),

          const SizedBox(height: 20),

          // Dynamic Tip Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.neutralBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.childAccent.withAlpha((0.15 * 255).round()),
                    shape: BoxShape.circle,
                  ),
                  child: const Text('✨', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mindful Tip of the Day',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.childTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getTipOfDay(),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.neutralMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternCard(DetectedPattern pattern) {
    final isPos = pattern.type == PatternType.positive;
    final isConcern = pattern.type == PatternType.concerning;

    final borderColor = isPos
        ? AppTheme.childSecondary
        : isConcern
            ? AppTheme.warningOrange
            : AppTheme.neutralBorder;

    final badgeColor = isPos
        ? AppTheme.childSecondary.withAlpha((0.15 * 255).round())
        : isConcern
            ? AppTheme.warningOrange.withAlpha((0.15 * 255).round())
            : AppTheme.neutralBg;

    final textColor = isPos
        ? AppTheme.childSecondary
        : isConcern
            ? AppTheme.warningOrange
            : AppTheme.neutralMuted;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: borderColor.withAlpha((0.5 * 255).round()), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(pattern.emoji, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(
                      pattern.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.childTextDark,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pattern.categoryLabel,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              pattern.description,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.neutralMuted),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.childSurface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tips_and_updates_rounded,
                      size: 14, color: AppTheme.childPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Coach Suggestion: ${pattern.suggestedAction}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.childPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(CoachingSession session) {
    final eval = session.previousGoalEvaluation;
    final dateStr =
        '${session.date.month}/${session.date.day}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.childPrimary.withAlpha((0.1 * 255).round()),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            session.statusEmoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
        title: Text(
          session.generatedGoal?.title ?? 'Daily Coaching Session',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
        ),
        subtitle: Text(
          eval != null
              ? '${eval.resultLabel} • ${eval.feedbackMessage}'
              : 'Usage: ${session.usageSnapshot.totalMinutes}m screen, ${session.usageSnapshot.focusMinutes}m focus',
          style: const TextStyle(fontSize: 11.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          dateStr,
          style: const TextStyle(
            color: AppTheme.neutralMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSnapshotStat(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha((0.85 * 255).round()),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _getTipOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning focus is high! Tackle your hardest learning challenge before noon.';
    } else if (hour < 17) {
      return 'Remember the 20-20-20 rule: every 20 minutes, look 20 feet away for 20 seconds!';
    } else {
      return 'Wind down before sleep. Swap screen time for a relaxing book or family chat tonight.';
    }
  }
}
