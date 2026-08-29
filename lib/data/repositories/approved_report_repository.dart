import '../models/approved_report_model.dart';
import '../../core/privacy/privacy_guard.dart';

abstract class ApprovedReportRepository {
  Future<List<ApprovedReport>> getApprovedReports(String childId);
  Future<ApprovedReport?> getApprovedReport(String reportId);
  Future<List<ApprovedReport>> getReportHistory(String childId,
      {ReportPeriod? period});
  Future<void> saveApprovedReport(ApprovedReport report);
  Future<List<ApprovedReport>> getMultiChildApprovedReports(
      List<String> childIds);
  Future<void> deleteApprovedReport(String reportId);
  Future<void> clearLocalCache();
}

/// In-memory implementation of ApprovedReportRepository for local offline and preview operation.
class InMemoryApprovedReportRepository implements ApprovedReportRepository {
  final Map<String, ApprovedReport> _reports = {};

  InMemoryApprovedReportRepository({bool seedSampleData = true}) {
    if (seedSampleData) {
      _seedDefaultSampleReports();
    }
  }

  void _seedDefaultSampleReports() {
    final now = DateTime.now();

    // Sample reports for child-1 ('Alex')
    final alexDailyToday = ApprovedReport(
      id: 'rep-alex-daily-today',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.daily,
      periodStart: DateTime(now.year, now.month, now.day),
      periodEnd: DateTime(now.year, now.month, now.day, 23, 59, 59),
      detailLevel: ReportDetailLevel.detailed,
      facts: const ReportFacts(
        totalScreenMinutes: 135,
        previousScreenMinutes: 150,
        changePercentage: -10.0,
        focusMinutes: 50,
        previousFocusMinutes: 35,
        focusChangePercentage: 42.8,
        breakCount: 4,
        previousBreakCount: 2,
        goalsCompletedCount: 2,
        goalsTotalCount: 3,
        achievementsUnlockedCount: 1,
        achievementsUnlocked: ['Focus Starter'],
        categoryBreakdown: {
          'Learning': 50,
          'Creativity': 35,
          'Entertainment': 50,
        },
        usageTrend: 'decreasing',
        screenUnlockCount: 18,
      ),
      insights: const [
        ApprovedInsight(
          id: 'ins-alex-1',
          type: InsightType.fact,
          category: ReportCategory.overallUsage,
          title: 'Healthy Usage Reduction',
          description:
              'Total recorded screen time decreased by 10% compared to yesterday.',
          evidence: AIEvidence(
            metric: 'Daily Screen Time',
            currentValue: '2h 15m',
            previousValue: '2h 30m',
            change: '-10.0%',
            sourceReportId: 'rep-alex-daily-today',
          ),
        ),
        ApprovedInsight(
          id: 'ins-alex-2',
          type: InsightType.fact,
          category: ReportCategory.focusTime,
          title: 'Strong Focus Engagement',
          description:
              'Engaged in 50m of dedicated learning and creative reading.',
          evidence: AIEvidence(
            metric: 'Focus Time',
            currentValue: '50m',
            previousValue: '35m',
            change: '+42.8%',
            sourceReportId: 'rep-alex-daily-today',
          ),
        ),
        ApprovedInsight(
          id: 'ins-alex-3',
          type: InsightType.suggestion,
          category: ReportCategory.breakSummary,
          title: 'Movement Routine',
          description:
              'Great job taking 4 movement breaks! Continue encouraging regular physical pauses.',
        ),
      ],
      summaryText:
          'Alex spent 2h 15m on connected devices today. Dedicated 50m to focused educational and creative engagement with 4 mindful movement pauses.',
      createdAt: now,
      isSnapshot: true,
    );

    final alexWeeklyCurrent = ApprovedReport(
      id: 'rep-alex-weekly-current',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: now.subtract(const Duration(days: 7)),
      periodEnd: now,
      detailLevel: ReportDetailLevel.detailed,
      facts: const ReportFacts(
        totalScreenMinutes: 872, // 14h 32m
        previousScreenMinutes: 778, // 12h 58m
        changePercentage: 12.1,
        focusMinutes: 370, // 6h 10m
        previousFocusMinutes: 320, // 5h 20m
        focusChangePercentage: 15.6,
        breakCount: 22,
        previousBreakCount: 18,
        goalsCompletedCount: 5,
        goalsTotalCount: 7,
        achievementsUnlockedCount: 2,
        achievementsUnlocked: ['Focus Starter', 'Break Master'],
        categoryBreakdown: {
          'Learning': 370,
          'Creativity': 210,
          'Entertainment': 292,
        },
        usageTrend: 'increasing',
        screenUnlockCount: 110,
      ),
      insights: const [
        ApprovedInsight(
          id: 'ins-alex-w1',
          type: InsightType.fact,
          category: ReportCategory.overallUsage,
          title: 'Screen Time Movement',
          description:
              'Total recorded screen time was 14h 32m, increasing 12.1% due to weekend project work.',
          evidence: AIEvidence(
            metric: 'Weekly Screen Time',
            currentValue: '14h 32m',
            previousValue: '12h 58m',
            change: '+12.1%',
            sourceReportId: 'rep-alex-weekly-current',
          ),
        ),
        ApprovedInsight(
          id: 'ins-alex-w2',
          type: InsightType.fact,
          category: ReportCategory.focusTime,
          title: 'Expanded Focus Hours',
          description:
              'Focused learning time increased by 15.6% to 6h 10m total.',
          evidence: AIEvidence(
            metric: 'Weekly Focus Time',
            currentValue: '6h 10m',
            previousValue: '5h 20m',
            change: '+15.6%',
            sourceReportId: 'rep-alex-weekly-current',
          ),
        ),
        ApprovedInsight(
          id: 'ins-alex-w3',
          type: InsightType.suggestion,
          category: ReportCategory.goals,
          title: 'Goal Momentum',
          description:
              'Achieved 5 out of 7 weekly goals. Discuss setting a weekend wind-down routine.',
        ),
      ],
      summaryText:
          'Alex spent 14h 32m on connected devices this week. Dedicated 6h 10m to focused educational and creative engagement.',
      createdAt: now.subtract(const Duration(hours: 2)),
      isSnapshot: true,
    );

    final alexWeeklyPrevious = ApprovedReport(
      id: 'rep-alex-weekly-prev',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: now.subtract(const Duration(days: 14)),
      periodEnd: now.subtract(const Duration(days: 7)),
      detailLevel: ReportDetailLevel.summary,
      facts: const ReportFacts(
        totalScreenMinutes: 778, // 12h 58m
        previousScreenMinutes: 810,
        changePercentage: -3.9,
        focusMinutes: 320, // 5h 20m
        previousFocusMinutes: 290,
        focusChangePercentage: 10.3,
        breakCount: 18,
        previousBreakCount: 15,
        goalsCompletedCount: 4,
        goalsTotalCount: 6,
        achievementsUnlockedCount: 1,
        achievementsUnlocked: ['Focus Starter'],
        categoryBreakdown: {
          'Learning': 320,
          'Creativity': 180,
          'Entertainment': 278,
        },
        usageTrend: 'stable',
        screenUnlockCount: 95,
      ),
      insights: const [],
      summaryText:
          'Alex spent 12h 58m on connected devices during the previous week, maintaining balanced habits.',
      createdAt: now.subtract(const Duration(days: 7)),
      isSnapshot: true,
    );

    final alexMonthly = ApprovedReport(
      id: 'rep-alex-monthly-august',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.monthly,
      periodStart: DateTime(now.year, now.month, 1),
      periodEnd: DateTime(now.year, now.month + 1, 0),
      detailLevel: ReportDetailLevel.detailed,
      facts: const ReportFacts(
        totalScreenMinutes: 3450,
        previousScreenMinutes: 3600,
        changePercentage: -4.1,
        focusMinutes: 1420,
        previousFocusMinutes: 1280,
        focusChangePercentage: 10.9,
        breakCount: 88,
        previousBreakCount: 72,
        goalsCompletedCount: 22,
        goalsTotalCount: 28,
        achievementsUnlockedCount: 3,
        achievementsUnlocked: ['Focus Starter', 'Break Master', 'Deep Focus'],
        categoryBreakdown: {
          'Learning': 1420,
          'Creativity': 850,
          'Entertainment': 1180,
        },
        usageTrend: 'decreasing',
        screenUnlockCount: 410,
      ),
      insights: const [
        ApprovedInsight(
          id: 'ins-alex-m1',
          type: InsightType.fact,
          category: ReportCategory.overallUsage,
          title: 'Monthly Balance Trend',
          description:
              'Maintained consistent screen time balance with a 4.1% overall reduction across August.',
        ),
      ],
      summaryText:
          'Alex maintained positive digital balance in August, spending 57h 30m total with 23h 40m devoted to focus and learning.',
      createdAt: now,
      isSnapshot: true,
    );

    _reports[alexDailyToday.id] = alexDailyToday;
    _reports[alexWeeklyCurrent.id] = alexWeeklyCurrent;
    _reports[alexWeeklyPrevious.id] = alexWeeklyPrevious;
    _reports[alexMonthly.id] = alexMonthly;

    // Sample report for child-2 ('Maya')
    final mayaWeekly = ApprovedReport(
      id: 'rep-maya-weekly-current',
      childId: 'child-2',
      childNickname: 'Maya',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: now.subtract(const Duration(days: 7)),
      periodEnd: now,
      detailLevel: ReportDetailLevel.summary,
      facts: const ReportFacts(
        totalScreenMinutes: 620, // 10h 20m
        previousScreenMinutes: 680,
        changePercentage: -8.8,
        focusMinutes: 290,
        previousFocusMinutes: 250,
        focusChangePercentage: 16.0,
        breakCount: 25,
        previousBreakCount: 20,
        goalsCompletedCount: 6,
        goalsTotalCount: 6,
        achievementsUnlockedCount: 2,
        achievementsUnlocked: ['Break Master', '7-Day Balance'],
        categoryBreakdown: {
          'Learning': 290,
          'Creativity': 180,
          'Entertainment': 150,
        },
        usageTrend: 'decreasing',
        screenUnlockCount: 75,
      ),
      insights: const [],
      summaryText:
          'Maya spent 10h 20m on connected devices this week with 100% goal completion.',
      createdAt: now,
      isSnapshot: true,
    );
    _reports[mayaWeekly.id] = mayaWeekly;
  }

  @override
  Future<List<ApprovedReport>> getApprovedReports(String childId) async {
    return _reports.values.where((r) => r.childId == childId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ApprovedReport?> getApprovedReport(String reportId) async {
    return _reports[reportId];
  }

  @override
  Future<List<ApprovedReport>> getReportHistory(String childId,
      {ReportPeriod? period}) async {
    final list = _reports.values
        .where((r) =>
            r.childId == childId && (period == null || r.period == period))
        .toList();
    list.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return list;
  }

  @override
  Future<void> saveApprovedReport(ApprovedReport report) async {
    // Architectural security assertion
    PrivacyGuard.assertCloudSafe(report.toJson());
    _reports[report.id] = report;
  }

  @override
  Future<List<ApprovedReport>> getMultiChildApprovedReports(
      List<String> childIds) async {
    final idSet = childIds.toSet();
    return _reports.values.where((r) => idSet.contains(r.childId)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> deleteApprovedReport(String reportId) async {
    _reports.remove(reportId);
  }

  @override
  Future<void> clearLocalCache() async {
    _reports.clear();
  }
}
