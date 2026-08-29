import '../../data/models/usage_models.dart';
import '../../data/models/achievement_model.dart';

/// LocalAnalyticsService performs 100% deterministic, on-device calculations.
///
/// CRITICAL PRIVACY & AI SAFETY:
/// Analytics engine produces ground truth facts.
/// The local LLM never calculates or modifies these metrics.
class LocalAnalyticsService {
  const LocalAnalyticsService();

  /// Calculates total usage and breakdown for a given date from raw local usage records.
  DailyUsage calculateDailyUsage({
    required List<UsageRecord> records,
    required DateTime date,
    int unlockCount = 0,
  }) {
    int totalSec = 0;
    int focusSec = 0;
    final categorySec = <String, int>{};
    final appMap = <String, AppUsageSummary>{};

    for (final r in records) {
      if (r.startTime.year == date.year &&
          r.startTime.month == date.month &&
          r.startTime.day == date.day) {
        totalSec += r.durationSeconds;
        categorySec[r.category] = (categorySec[r.category] ?? 0) + r.durationSeconds;

        if (r.category.toLowerCase().contains('learn') ||
            r.category.toLowerCase().contains('educat') ||
            r.category.toLowerCase().contains('read') ||
            r.category.toLowerCase().contains('creativ')) {
          focusSec += r.durationSeconds;
        }

        final existing = appMap[r.packageName];
        final durMin = (r.durationSeconds / 60).round();
        if (existing != null) {
          appMap[r.packageName] = AppUsageSummary(
            packageName: r.packageName,
            appName: r.appName,
            category: r.category,
            durationMinutes: existing.durationMinutes + durMin,
            launchCount: existing.launchCount + 1,
          );
        } else {
          appMap[r.packageName] = AppUsageSummary(
            packageName: r.packageName,
            appName: r.appName,
            category: r.category,
            durationMinutes: durMin,
            launchCount: 1,
          );
        }
      }
    }

    final catMinutes = categorySec.map((k, v) => MapEntry(k, (v / 60).round()));
    final apps = appMap.values.toList()
      ..sort((a, b) => b.durationMinutes.compareTo(a.durationMinutes));

    return DailyUsage(
      date: date,
      totalMinutes: (totalSec / 60).round(),
      focusMinutes: (focusSec / 60).round(),
      unlockCount: unlockCount,
      categoryMinutes: catMinutes,
      topApps: apps,
    );
  }

  /// Calculates weekly usage aggregated statistics.
  int calculateWeeklyTotal(List<DailyUsage> dailyList) {
    return dailyList.fold<int>(0, (sum, item) => sum + item.totalMinutes);
  }

  /// Calculates weekly average daily usage in minutes.
  int calculateWeeklyDailyAverage(List<DailyUsage> dailyList) {
    if (dailyList.isEmpty) return 0;
    final total = calculateWeeklyTotal(dailyList);
    return (total / dailyList.length).round();
  }

  /// Calculates percentage change between two values (e.g. today vs yesterday).
  double calculateUsageChange(int todayMinutes, int yesterdayMinutes) {
    if (yesterdayMinutes <= 0) {
      return todayMinutes > 0 ? 100.0 : 0.0;
    }
    final change = ((todayMinutes - yesterdayMinutes) / yesterdayMinutes) * 100.0;
    return double.parse(change.toStringAsFixed(1));
  }

  /// Calculates category breakdown and percentages from usage records.
  List<CategoryUsage> calculateCategoryBreakdown(List<UsageRecord> records) {
    if (records.isEmpty) return [];

    final categorySec = <String, int>{};
    final categoryApps = <String, Set<String>>{};
    int totalSec = 0;

    for (final r in records) {
      totalSec += r.durationSeconds;
      categorySec[r.category] = (categorySec[r.category] ?? 0) + r.durationSeconds;
      categoryApps.putIfAbsent(r.category, () => <String>{}).add(r.packageName);
    }

    if (totalSec == 0) return [];

    final result = <CategoryUsage>[];
    categorySec.forEach((cat, sec) {
      final totalMin = (sec / 60).round();
      final percentage = double.parse(((sec / totalSec) * 100.0).toStringAsFixed(1));
      result.add(CategoryUsage(
        category: cat,
        totalMinutes: totalMin,
        percentage: percentage,
        appCount: categoryApps[cat]?.length ?? 1,
      ));
    });

    result.sort((a, b) => b.totalMinutes.compareTo(a.totalMinutes));
    return result;
  }

  /// Calculates total focus time from focus sessions.
  int calculateFocusTime(List<FocusSession> sessions) {
    return sessions
        .where((s) => s.isCompleted)
        .fold<int>(0, (sum, s) => sum + s.actualMinutes);
  }

  /// Calculates break frequency from usage timeline gaps (>5 min screen-off).
  int calculateBreakFrequency(List<UsageTimelineEntry> timeline) {
    if (timeline.length < 2) return 0;

    // Sort timeline chronologically
    final sorted = List<UsageTimelineEntry>.from(timeline)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    int breaks = 0;
    for (int i = 0; i < sorted.length - 1; i++) {
      final currentEnd = sorted[i].endTime;
      final nextStart = sorted[i + 1].startTime;
      final gapMinutes = nextStart.difference(currentEnd).inMinutes;

      // Gap of 5 minutes or more counts as a healthy mindful break
      if (gapMinutes >= 5) {
        breaks++;
      }
    }

    return breaks;
  }

  /// Evaluates trend direction: 'decreasing' (positive for screen balance), 'increasing', or 'stable'.
  String calculateUsageTrend(List<DailyUsage> dailyList) {
    if (dailyList.length < 2) return 'stable';

    final firstHalf = dailyList.sublist(0, dailyList.length ~/ 2);
    final secondHalf = dailyList.sublist(dailyList.length ~/ 2);

    final avg1 = calculateWeeklyDailyAverage(firstHalf);
    final avg2 = calculateWeeklyDailyAverage(secondHalf);

    final diff = avg2 - avg1;
    if (diff > 15) return 'increasing';
    if (diff < -15) return 'decreasing';
    return 'stable';
  }

  /// Evaluates whether an achievement is met based on local facts.
  bool evaluateAchievementCriteria({
    required AchievementType type,
    required int focusMinutes,
    required int breakCount,
    required int consecutiveDaysGoalMet,
    required int maxSingleFocusSession,
  }) {
    switch (type) {
      case AchievementType.focusStarter:
        return focusMinutes >= 20;
      case AchievementType.breakMaster:
        return breakCount >= 5;
      case AchievementType.deepFocus:
        return maxSingleFocusSession >= 30;
      case AchievementType.sevenDayBalance:
        return consecutiveDaysGoalMet >= 7;
      case AchievementType.consistencyChampion:
        return consecutiveDaysGoalMet >= 14;
    }
  }
}
