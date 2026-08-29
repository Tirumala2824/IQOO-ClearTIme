import '../../data/models/approved_report_model.dart';
import '../../data/models/usage_models.dart';
import '../../core/privacy/child_report_privacy_filter.dart';

/// ChildReportBuilder generates deterministic, privacy-safe approved reports
/// entirely on the child device.
///
/// IMMUTABILITY & SAFETY:
/// 1. Numerical facts are computed deterministically.
/// 2. Reports function 100% when AI is disabled.
/// 3. Historical snapshots remain immutable.
class ChildReportBuilder {
  final ChildReportPrivacyFilter _privacyFilter;
  final String analyticsVersion;
  final String contextVersion;
  final String configVersion;

  const ChildReportBuilder({
    ChildReportPrivacyFilter privacyFilter = const ChildReportPrivacyFilter(),
    this.analyticsVersion = '1.0.0',
    this.contextVersion = '1.0.0',
    this.configVersion = '1.0.0',
  }) : _privacyFilter = privacyFilter;

  /// Builds a deterministic Daily Approved Report.
  ApprovedReport buildDailyReport({
    required String childId,
    required String childNickname,
    required String familyId,
    required DateTime date,
    required DailyUsage currentDaily,
    DailyUsage? previousDaily,
    int focusMinutes = 0,
    int previousFocusMinutes = 0,
    int breakCount = 0,
    int previousBreakCount = 0,
    int goalsCompleted = 0,
    int goalsTotal = 0,
    int achievementsUnlockedCount = 0,
    List<String> unlockedBadgeTitles = const [],
    ParentReportSettings settings = const ParentReportSettings(),
    String? customReportId,
  }) {
    final reportId = customReportId ??
        'rep-daily-$childId-${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

    final facts = _privacyFilter.filterFacts(
      currentDaily: currentDaily,
      previousDaily: previousDaily,
      focusMinutes: focusMinutes,
      previousFocusMinutes: previousFocusMinutes,
      breakCount: breakCount,
      previousBreakCount: previousBreakCount,
      goalsCompleted: goalsCompleted,
      goalsTotal: goalsTotal,
      achievementsUnlockedCount: achievementsUnlockedCount,
      unlockedBadgeTitles: unlockedBadgeTitles,
      usageTrend: currentDaily.totalMinutes >= (previousDaily?.totalMinutes ?? 0)
          ? (currentDaily.totalMinutes - (previousDaily?.totalMinutes ?? 0) > 15
              ? 'increasing'
              : 'stable')
          : (previousDaily != null &&
                  previousDaily.totalMinutes - currentDaily.totalMinutes > 15
              ? 'decreasing'
              : 'stable'),
      allowedCategories: settings.categories,
    );

    final insights = _privacyFilter.generateApprovedInsights(
      facts: facts,
      categories: settings.categories,
      reportId: reportId,
    );

    final summary = _generateDeterministicSummary(
      period: ReportPeriod.daily,
      childNickname: childNickname,
      facts: facts,
      categories: settings.categories,
    );

    return ApprovedReport(
      id: reportId,
      childId: childId,
      childNickname: childNickname,
      familyId: familyId,
      period: ReportPeriod.daily,
      periodStart: DateTime(date.year, date.month, date.day),
      periodEnd: DateTime(date.year, date.month, date.day, 23, 59, 59),
      detailLevel: settings.detail,
      categories: settings.categories,
      facts: facts,
      insights: insights,
      summaryText: summary,
      contextVersion: contextVersion,
      privacyFilterVersion: _privacyFilter.version,
      analyticsVersion: analyticsVersion,
      configVersion: configVersion,
      createdAt: DateTime.now(),
      isSnapshot: true,
    );
  }

  /// Builds a deterministic Weekly Approved Report.
  ApprovedReport buildWeeklyReport({
    required String childId,
    required String childNickname,
    required String familyId,
    required DateTime weekStart,
    required DateTime weekEnd,
    required List<DailyUsage> dailyUsages,
    List<DailyUsage> previousWeekUsages = const [],
    int totalFocusMinutes = 0,
    int previousTotalFocusMinutes = 0,
    int totalBreakCount = 0,
    int previousTotalBreakCount = 0,
    int goalsCompleted = 0,
    int goalsTotal = 0,
    int achievementsUnlockedCount = 0,
    List<String> unlockedBadgeTitles = const [],
    ParentReportSettings settings = const ParentReportSettings(),
    String? customReportId,
  }) {
    final reportId = customReportId ??
        'rep-weekly-$childId-${weekStart.year}w${((weekStart.day / 7).ceil())}';

    final totalMinutes =
        dailyUsages.fold<int>(0, (sum, d) => sum + d.totalMinutes);
    final prevTotalMinutes =
        previousWeekUsages.fold<int>(0, (sum, d) => sum + d.totalMinutes);

    final aggregatedCategories = <String, int>{};
    for (final d in dailyUsages) {
      d.categoryMinutes.forEach((cat, min) {
        aggregatedCategories[cat] = (aggregatedCategories[cat] ?? 0) + min;
      });
    }

    final aggregatedDaily = DailyUsage(
      date: weekStart,
      totalMinutes: totalMinutes,
      focusMinutes: totalFocusMinutes,
      categoryMinutes: aggregatedCategories,
      unlockCount: dailyUsages.fold<int>(0, (sum, d) => sum + d.unlockCount),
    );

    final aggregatedPrevDaily = DailyUsage(
      date: weekStart.subtract(const Duration(days: 7)),
      totalMinutes: prevTotalMinutes,
      focusMinutes: previousTotalFocusMinutes,
    );

    final trend = prevTotalMinutes > 0
        ? (totalMinutes - prevTotalMinutes > 60
            ? 'increasing'
            : (prevTotalMinutes - totalMinutes > 60 ? 'decreasing' : 'stable'))
        : 'stable';

    final facts = _privacyFilter.filterFacts(
      currentDaily: aggregatedDaily,
      previousDaily: aggregatedPrevDaily,
      focusMinutes: totalFocusMinutes,
      previousFocusMinutes: previousTotalFocusMinutes,
      breakCount: totalBreakCount,
      previousBreakCount: previousTotalBreakCount,
      goalsCompleted: goalsCompleted,
      goalsTotal: goalsTotal,
      achievementsUnlockedCount: achievementsUnlockedCount,
      unlockedBadgeTitles: unlockedBadgeTitles,
      usageTrend: trend,
      allowedCategories: settings.categories,
    );

    final insights = _privacyFilter.generateApprovedInsights(
      facts: facts,
      categories: settings.categories,
      reportId: reportId,
    );

    final summary = _generateDeterministicSummary(
      period: ReportPeriod.weekly,
      childNickname: childNickname,
      facts: facts,
      categories: settings.categories,
    );

    return ApprovedReport(
      id: reportId,
      childId: childId,
      childNickname: childNickname,
      familyId: familyId,
      period: ReportPeriod.weekly,
      periodStart: weekStart,
      periodEnd: weekEnd,
      detailLevel: settings.detail,
      categories: settings.categories,
      facts: facts,
      insights: insights,
      summaryText: summary,
      contextVersion: contextVersion,
      privacyFilterVersion: _privacyFilter.version,
      analyticsVersion: analyticsVersion,
      configVersion: configVersion,
      createdAt: DateTime.now(),
      isSnapshot: true,
    );
  }

  /// Builds a deterministic Monthly Approved Report.
  ApprovedReport buildMonthlyReport({
    required String childId,
    required String childNickname,
    required String familyId,
    required int year,
    required int month,
    required int totalMinutes,
    int previousMonthMinutes = 0,
    int totalFocusMinutes = 0,
    int previousMonthFocusMinutes = 0,
    int totalBreakCount = 0,
    int previousMonthBreakCount = 0,
    int goalsCompleted = 0,
    int goalsTotal = 0,
    int achievementsUnlockedCount = 0,
    List<String> unlockedBadgeTitles = const [],
    Map<String, int> categoryDistribution = const {},
    ParentReportSettings settings = const ParentReportSettings(),
    String? customReportId,
  }) {
    final reportId = customReportId ??
        'rep-monthly-$childId-$year-${month.toString().padLeft(2, '0')}';

    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0, 23, 59, 59);

    final currentDaily = DailyUsage(
      date: monthStart,
      totalMinutes: totalMinutes,
      focusMinutes: totalFocusMinutes,
      categoryMinutes: categoryDistribution,
    );

    final prevDaily = DailyUsage(
      date: DateTime(year, month - 1, 1),
      totalMinutes: previousMonthMinutes,
      focusMinutes: previousMonthFocusMinutes,
    );

    final trend = previousMonthMinutes > 0
        ? (totalMinutes - previousMonthMinutes > 120
            ? 'increasing'
            : (previousMonthMinutes - totalMinutes > 120 ? 'decreasing' : 'stable'))
        : 'stable';

    final facts = _privacyFilter.filterFacts(
      currentDaily: currentDaily,
      previousDaily: prevDaily,
      focusMinutes: totalFocusMinutes,
      previousFocusMinutes: previousMonthFocusMinutes,
      breakCount: totalBreakCount,
      previousBreakCount: previousMonthBreakCount,
      goalsCompleted: goalsCompleted,
      goalsTotal: goalsTotal,
      achievementsUnlockedCount: achievementsUnlockedCount,
      unlockedBadgeTitles: unlockedBadgeTitles,
      usageTrend: trend,
      allowedCategories: settings.categories,
    );

    final insights = _privacyFilter.generateApprovedInsights(
      facts: facts,
      categories: settings.categories,
      reportId: reportId,
    );

    final summary = _generateDeterministicSummary(
      period: ReportPeriod.monthly,
      childNickname: childNickname,
      facts: facts,
      categories: settings.categories,
    );

    return ApprovedReport(
      id: reportId,
      childId: childId,
      childNickname: childNickname,
      familyId: familyId,
      period: ReportPeriod.monthly,
      periodStart: monthStart,
      periodEnd: monthEnd,
      detailLevel: settings.detail,
      categories: settings.categories,
      facts: facts,
      insights: insights,
      summaryText: summary,
      contextVersion: contextVersion,
      privacyFilterVersion: _privacyFilter.version,
      analyticsVersion: analyticsVersion,
      configVersion: configVersion,
      createdAt: DateTime.now(),
      isSnapshot: true,
    );
  }

  String _generateDeterministicSummary({
    required ReportPeriod period,
    required String childNickname,
    required ReportFacts facts,
    required Set<ReportCategory> categories,
  }) {
    final buffer = StringBuffer();
    final periodName = period == ReportPeriod.daily
        ? 'today'
        : (period == ReportPeriod.weekly ? 'this week' : 'this month');

    buffer.write('$childNickname spent ${facts.formattedTotalTime} on connected devices $periodName.');

    if (categories.contains(ReportCategory.focusTime) && facts.focusMinutes > 0) {
      buffer.write(' Dedicated ${facts.formattedFocusTime} to focused educational and creative engagement.');
    }

    if (categories.contains(ReportCategory.breakSummary) && facts.breakCount > 0) {
      buffer.write(' Maintained balance with ${facts.breakCount} mindful movement pauses.');
    }

    if (categories.contains(ReportCategory.goals) && facts.goalsTotalCount > 0) {
      buffer.write(' Successfully achieved ${facts.goalsCompletedCount} of ${facts.goalsTotalCount} mindful goals.');
    }

    return buffer.toString();
  }
}
