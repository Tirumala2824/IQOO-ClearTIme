import '../../data/models/coaching_models.dart';
import '../../data/models/usage_models.dart';
import 'package:uuid/uuid.dart';

/// Deterministic pattern detection engine.
///
/// Analyzes usage data to identify positive habits, concerning trends,
/// and neutral observations. 100% local, no AI required.
class PatternDetectionService {
  const PatternDetectionService();

  /// Detects patterns from today's usage and historical weekly data.
  List<DetectedPattern> detectPatterns({
    required UsageSummary todayUsage,
    required List<DailyUsage> weeklyHistory,
  }) {
    final patterns = <DetectedPattern>[];
    final now = DateTime.now();
    const uuid = Uuid();

    // Calculate weekly averages for comparison
    final avgTotal = weeklyHistory.isEmpty
        ? 0
        : weeklyHistory.fold<int>(0, (s, d) => s + d.totalMinutes) ~/
            weeklyHistory.length;
    final avgFocus = weeklyHistory.isEmpty
        ? 0
        : weeklyHistory.fold<int>(0, (s, d) => s + d.focusMinutes) ~/
            weeklyHistory.length;

    // ── 1. Focus Time Patterns ──
    if (todayUsage.focusMinutes >= 60) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.positive,
        category: PatternCategory.focusTime,
        title: 'Strong Focus Session',
        description:
            'You achieved ${todayUsage.focusMinutes}m of focused learning today — that\'s excellent!',
        suggestedAction: 'Keep this momentum going with a similar focus goal tomorrow.',
        evidence: {
          'focusMinutes': todayUsage.focusMinutes.toDouble(),
          'weeklyAvgFocus': avgFocus.toDouble(),
        },
        detectedAt: now,
      ));
    } else if (todayUsage.focusMinutes < 30 && todayUsage.totalMinutes > 60) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.concerning,
        category: PatternCategory.focusTime,
        title: 'Focus Time Below Average',
        description:
            'Only ${todayUsage.focusMinutes}m of focus out of ${todayUsage.totalMinutes}m total screen time. '
            'Your weekly average is ${avgFocus}m.',
        suggestedAction:
            'Try a short 20-minute focused learning session to build the habit.',
        evidence: {
          'focusMinutes': todayUsage.focusMinutes.toDouble(),
          'totalMinutes': todayUsage.totalMinutes.toDouble(),
          'focusRatio': todayUsage.totalMinutes > 0
              ? (todayUsage.focusMinutes / todayUsage.totalMinutes)
              : 0.0,
        },
        detectedAt: now,
      ));
    }

    // ── 2. Break Habit Patterns ──
    if (todayUsage.breakCount >= 4) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.positive,
        category: PatternCategory.breakHabits,
        title: 'Healthy Break Routine',
        description:
            'You took ${todayUsage.breakCount} mindful breaks today — great for your eyes and mind!',
        suggestedAction:
            'Maintain this habit. Regular breaks improve focus and wellbeing.',
        evidence: {
          'breakCount': todayUsage.breakCount.toDouble(),
        },
        detectedAt: now,
      ));
    } else if (todayUsage.breakCount < 2 && todayUsage.totalMinutes > 90) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.concerning,
        category: PatternCategory.breakHabits,
        title: 'Few Screen Breaks',
        description:
            'Only ${todayUsage.breakCount} breaks during ${todayUsage.totalMinutes}m of screen time. '
            'Regular pauses help keep your eyes healthy.',
        suggestedAction:
            'Try the 20-20-20 rule: every 20 minutes, look 20 feet away for 20 seconds.',
        evidence: {
          'breakCount': todayUsage.breakCount.toDouble(),
          'totalMinutes': todayUsage.totalMinutes.toDouble(),
        },
        detectedAt: now,
      ));
    }

    // ── 3. Gaming / Entertainment Patterns ──
    final gamingMinutes = _getCategoryMinutes(todayUsage, 'game');
    final gamingRatio = todayUsage.totalMinutes > 0
        ? gamingMinutes / todayUsage.totalMinutes
        : 0.0;

    if (gamingRatio > 0.5 && gamingMinutes > 60) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.concerning,
        category: PatternCategory.gaming,
        title: 'Gaming Dominant',
        description:
            'Gaming took up ${gamingMinutes}m (${(gamingRatio * 100).round()}%) of your screen time today.',
        suggestedAction:
            'Balance gaming with some creative or learning time. Try a 30-minute swap!',
        evidence: {
          'gamingMinutes': gamingMinutes.toDouble(),
          'gamingRatio': gamingRatio,
        },
        detectedAt: now,
      ));
    } else if (gamingMinutes > 0 && gamingRatio <= 0.35) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.positive,
        category: PatternCategory.gaming,
        title: 'Balanced Gaming',
        description:
            'Gaming was ${gamingMinutes}m (${(gamingRatio * 100).round()}%) — a healthy balance!',
        suggestedAction: 'Great balance between play and learning. Keep it up!',
        evidence: {
          'gamingMinutes': gamingMinutes.toDouble(),
          'gamingRatio': gamingRatio,
        },
        detectedAt: now,
      ));
    }

    // ── 4. Overall Screen Time Trends ──
    if (todayUsage.changePercentageFromYesterday < -10) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.positive,
        category: PatternCategory.improvement,
        title: 'Screen Time Reduced',
        description:
            'Your screen time decreased ${todayUsage.changePercentageFromYesterday.abs().toStringAsFixed(0)}% compared to yesterday!',
        suggestedAction:
            'Excellent progress toward a healthier balance. Keep making mindful choices.',
        evidence: {
          'changePercent': todayUsage.changePercentageFromYesterday,
          'todayTotal': todayUsage.totalMinutes.toDouble(),
        },
        detectedAt: now,
      ));
    } else if (todayUsage.changePercentageFromYesterday > 25) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.concerning,
        category: PatternCategory.screenTotal,
        title: 'Screen Time Spike',
        description:
            'Screen time jumped ${todayUsage.changePercentageFromYesterday.toStringAsFixed(0)}% vs yesterday '
            '(${todayUsage.totalMinutes}m today vs ~${avgTotal}m average).',
        suggestedAction:
            'That\'s okay! Tomorrow, try setting a gentle time goal and sticking to it.',
        evidence: {
          'changePercent': todayUsage.changePercentageFromYesterday,
          'todayTotal': todayUsage.totalMinutes.toDouble(),
          'weeklyAvg': avgTotal.toDouble(),
        },
        detectedAt: now,
      ));
    }

    // ── 5. Learning Streak Detection ──
    final learningMinutes = _getCategoryMinutes(todayUsage, 'learn') +
        _getCategoryMinutes(todayUsage, 'educat');
    if (learningMinutes > 45) {
      final consecutiveLearningDays = _countConsecutiveDays(
        weeklyHistory,
        (day) {
          final eduMin = (day.categoryMinutes['Education'] ?? 0) +
              (day.categoryMinutes['Education & Learning'] ?? 0);
          return eduMin > 30;
        },
      );
      if (consecutiveLearningDays >= 3) {
        patterns.add(DetectedPattern(
          id: uuid.v4(),
          type: PatternType.positive,
          category: PatternCategory.learningStreak,
          title: 'Learning Streak: $consecutiveLearningDays Days!',
          description:
              'You\'ve had $consecutiveLearningDays consecutive days with 30+ minutes of learning. Amazing commitment!',
          suggestedAction:
              'You\'re building a strong habit! Can you extend the streak to ${consecutiveLearningDays + 1} days?',
          evidence: {
            'streakDays': consecutiveLearningDays.toDouble(),
            'todayLearning': learningMinutes.toDouble(),
          },
          detectedAt: now,
        ));
      }
    }

    // ── 6. Balance Shift Detection ──
    if (todayUsage.categories.length >= 3) {
      final top = todayUsage.categories.first;
      final second = todayUsage.categories.length > 1
          ? todayUsage.categories[1]
          : null;
      if (second != null &&
          top.percentage > 60 &&
          top.category.toLowerCase().contains('game')) {
        patterns.add(DetectedPattern(
          id: uuid.v4(),
          type: PatternType.concerning,
          category: PatternCategory.balanceShift,
          title: 'Activity Imbalance',
          description:
              '${top.category} dominates at ${top.percentage.round()}% while '
              '${second.category} is only ${second.percentage.round()}%.',
          suggestedAction:
              'Try swapping 15 minutes of ${top.category} for ${second.category} tomorrow.',
          evidence: {
            'topPercent': top.percentage,
            'secondPercent': second.percentage,
          },
          detectedAt: now,
        ));
      }
    }

    // Ensure we always return at least one neutral observation
    if (patterns.isEmpty) {
      patterns.add(DetectedPattern(
        id: uuid.v4(),
        type: PatternType.neutral,
        category: PatternCategory.screenTotal,
        title: 'Steady Day',
        description:
            'Screen time of ${todayUsage.totalMinutes}m with ${todayUsage.focusMinutes}m focus. '
            'A balanced, normal day!',
        suggestedAction:
            'Keep maintaining this consistency. Small daily improvements add up!',
        evidence: {
          'totalMinutes': todayUsage.totalMinutes.toDouble(),
          'focusMinutes': todayUsage.focusMinutes.toDouble(),
        },
        detectedAt: now,
      ));
    }

    return patterns;
  }

  /// Extracts total minutes for a category (case-insensitive partial match).
  int _getCategoryMinutes(UsageSummary usage, String keyword) {
    int total = 0;
    for (final cat in usage.categories) {
      if (cat.category.toLowerCase().contains(keyword.toLowerCase())) {
        total += cat.totalMinutes;
      }
    }
    return total;
  }

  /// Counts consecutive days (most recent first) matching a condition.
  int _countConsecutiveDays(
    List<DailyUsage> history,
    bool Function(DailyUsage) condition,
  ) {
    if (history.isEmpty) return 0;
    final sorted = List<DailyUsage>.from(history)
      ..sort((a, b) => b.date.compareTo(a.date));
    int count = 0;
    for (final day in sorted) {
      if (condition(day)) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }
}
