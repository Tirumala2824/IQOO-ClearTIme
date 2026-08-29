import '../../data/models/approved_report_model.dart';
import '../../data/models/usage_models.dart';

/// ChildReportPrivacyFilter enforces strict, field-level data minimization
/// before any child analytics leave the local child device.
///
/// CRITICAL ARCHITECTURAL BOUNDARY:
/// 1. Disallows raw package names, exact timestamps, and timeline records.
/// 2. Disallows private child reflections and mood diary notes.
/// 3. Disallows raw device diagnostics or background system events.
/// 4. Filters output strictly based on the parent-configured sharing categories.
class ChildReportPrivacyFilter {
  final String version;

  const ChildReportPrivacyFilter({this.version = '1.0.0'});

  /// Filters local daily analytics facts into privacy-safe ReportFacts.
  ReportFacts filterFacts({
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
    String usageTrend = 'stable',
    Set<ReportCategory> allowedCategories = const {
      ReportCategory.overallUsage,
      ReportCategory.usageTrend,
      ReportCategory.focusTime,
      ReportCategory.breakSummary,
      ReportCategory.goals,
      ReportCategory.achievements,
      ReportCategory.categorySummary,
    },
  }) {
    final prevTotal = previousDaily?.totalMinutes ?? 0;
    final changePct = prevTotal > 0
        ? ((currentDaily.totalMinutes - prevTotal) / prevTotal) * 100.0
        : (currentDaily.totalMinutes > 0 ? 100.0 : 0.0);

    final focusChangePct = previousFocusMinutes > 0
        ? ((focusMinutes - previousFocusMinutes) / previousFocusMinutes) * 100.0
        : (focusMinutes > 0 ? 100.0 : 0.0);

    // Filter categories: remove any package names or app-level identifiers
    // Only high-level category buckets (e.g. 'Learning', 'Productivity', 'Entertainment') are preserved.
    final sanitizedCategories = <String, int>{};
    if (allowedCategories.contains(ReportCategory.categorySummary)) {
      currentDaily.categoryMinutes.forEach((category, minutes) {
        // Clean category name, ensuring no package-like syntax (e.g. 'com.example...')
        final cleanCategory = category.contains('.') ? 'Other' : category;
        sanitizedCategories[cleanCategory] = minutes;
      });
    }

    return ReportFacts(
      totalScreenMinutes: allowedCategories.contains(ReportCategory.overallUsage)
          ? currentDaily.totalMinutes
          : 0,
      previousScreenMinutes:
          allowedCategories.contains(ReportCategory.overallUsage) ? prevTotal : 0,
      changePercentage: allowedCategories.contains(ReportCategory.usageTrend)
          ? double.parse(changePct.toStringAsFixed(1))
          : 0.0,
      focusMinutes: allowedCategories.contains(ReportCategory.focusTime)
          ? focusMinutes
          : 0,
      previousFocusMinutes: allowedCategories.contains(ReportCategory.focusTime)
          ? previousFocusMinutes
          : 0,
      focusChangePercentage: allowedCategories.contains(ReportCategory.focusTime)
          ? double.parse(focusChangePct.toStringAsFixed(1))
          : 0.0,
      breakCount: allowedCategories.contains(ReportCategory.breakSummary)
          ? breakCount
          : 0,
      previousBreakCount: allowedCategories.contains(ReportCategory.breakSummary)
          ? previousBreakCount
          : 0,
      goalsCompletedCount:
          allowedCategories.contains(ReportCategory.goals) ? goalsCompleted : 0,
      goalsTotalCount:
          allowedCategories.contains(ReportCategory.goals) ? goalsTotal : 0,
      achievementsUnlockedCount: allowedCategories
              .contains(ReportCategory.achievements)
          ? achievementsUnlockedCount
          : 0,
      achievementsUnlocked:
          allowedCategories.contains(ReportCategory.achievements)
              ? List<String>.unmodifiable(unlockedBadgeTitles)
              : const [],
      categoryBreakdown: Map<String, int>.unmodifiable(sanitizedCategories),
      usageTrend: allowedCategories.contains(ReportCategory.usageTrend)
          ? usageTrend
          : 'stable',
      screenUnlockCount:
          allowedCategories.contains(ReportCategory.overallUsage)
              ? currentDaily.unlockCount
              : 0,
    );
  }

  /// Builds approved insight cards strictly from factual metrics.
  List<ApprovedInsight> generateApprovedInsights({
    required ReportFacts facts,
    required Set<ReportCategory> categories,
    String reportId = '',
  }) {
    final insights = <ApprovedInsight>[];

    // 1. Overall Screen Time & Trend Fact
    if (categories.contains(ReportCategory.overallUsage) &&
        categories.contains(ReportCategory.usageTrend)) {
      final changeSign = facts.changePercentage >= 0 ? '+' : '';
      insights.add(
        ApprovedInsight(
          id: 'insight-usage-$reportId',
          type: InsightType.fact,
          category: ReportCategory.overallUsage,
          title: 'Screen Time Movement',
          description:
              'Total recorded screen time is ${facts.formattedTotalTime} ($changeSign${facts.changePercentage}% change).',
          evidence: AIEvidence(
            metric: 'Total Screen Time',
            currentValue: facts.formattedTotalTime,
            previousValue: '${facts.previousScreenMinutes ~/ 60}h ${facts.previousScreenMinutes % 60}m',
            change: '$changeSign${facts.changePercentage}%',
            sourceReportId: reportId,
          ),
        ),
      );
    }

    // 2. Focus Time Fact
    if (categories.contains(ReportCategory.focusTime)) {
      insights.add(
        ApprovedInsight(
          id: 'insight-focus-$reportId',
          type: InsightType.fact,
          category: ReportCategory.focusTime,
          title: 'Mindful Learning & Focus',
          description:
              'Engaged in ${facts.formattedFocusTime} of concentrated learning and creative activities.',
          evidence: AIEvidence(
            metric: 'Focus Time',
            currentValue: facts.formattedFocusTime,
            previousValue: '${facts.previousFocusMinutes}m',
            change: '${facts.focusChangePercentage >= 0 ? "+" : ""}${facts.focusChangePercentage}%',
            sourceReportId: reportId,
          ),
        ),
      );
    }

    // 3. Movement Breaks Suggestion / Fact
    if (categories.contains(ReportCategory.breakSummary)) {
      if (facts.breakCount >= 3) {
        insights.add(
          ApprovedInsight(
            id: 'insight-break-$reportId',
            type: InsightType.fact,
            category: ReportCategory.breakSummary,
            title: 'Consistent Movement Pauses',
            description:
                'Took ${facts.breakCount} mindful pauses between digital sessions, supporting healthy eye and body balance.',
            evidence: AIEvidence(
              metric: 'Mindful Breaks',
              currentValue: '${facts.breakCount} breaks',
              previousValue: '${facts.previousBreakCount} breaks',
              change: '${facts.breakCount - facts.previousBreakCount >= 0 ? "+" : ""}${facts.breakCount - facts.previousBreakCount}',
              sourceReportId: reportId,
            ),
          ),
        );
      } else {
        insights.add(
          ApprovedInsight(
            id: 'insight-break-sugg-$reportId',
            type: InsightType.suggestion,
            category: ReportCategory.breakSummary,
            title: 'Movement Pause Routine',
            description:
                'Consider scheduling a family stretch or outdoor break after 45 minutes of continuous device use.',
          ),
        );
      }
    }

    // 4. Goals Progress Fact
    if (categories.contains(ReportCategory.goals) && facts.goalsTotalCount > 0) {
      insights.add(
        ApprovedInsight(
          id: 'insight-goals-$reportId',
          type: InsightType.fact,
          category: ReportCategory.goals,
          title: 'Wellbeing Goals Completed',
          description:
              'Completed ${facts.goalsCompletedCount} of ${facts.goalsTotalCount} active mindful goals.',
        ),
      );
    }

    // 5. Unlocked Achievements Fact
    if (categories.contains(ReportCategory.achievements) &&
        facts.achievementsUnlocked.isNotEmpty) {
      insights.add(
        ApprovedInsight(
          id: 'insight-achievements-$reportId',
          type: InsightType.fact,
          category: ReportCategory.achievements,
          title: 'Milestones Unlocked',
          description:
              'Earned milestone badges: ${facts.achievementsUnlocked.join(", ")}.',
        ),
      );
    }

    return insights;
  }
}
