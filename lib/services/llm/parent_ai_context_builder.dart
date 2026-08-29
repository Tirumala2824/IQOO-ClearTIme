import '../../data/models/llm_models.dart';
import '../../data/models/usage_models.dart';

/// ParentAIContextBuilder builds strictly approved parent report context.
///
/// CRITICAL PRIVACY INVARIANT:
/// 1. Raw child device timestamps are filtered out.
/// 2. Raw private child reflections are never exposed.
/// 3. Hidden device status and background logs are never included.
/// 4. Only parent-approved aggregated summaries enter the prompt.
class ParentAIContextBuilder {
  const ParentAIContextBuilder();

  /// Builds a sanitized parent report context.
  ParentAIApprovedReportContext buildContext({
    required String childNickname,
    required UsageSummary usageSummary,
    int goalsCompleted = 0,
    int goalsTotal = 0,
    List<String> activeAlerts = const [],
    String reportDateFormatted = 'Today',
  }) {
    final topCategory = usageSummary.categories.isNotEmpty
        ? usageSummary.categories.first.category
        : 'General Learning';

    return ParentAIApprovedReportContext(
      childNickname: childNickname,
      totalScreenMinutes: usageSummary.totalMinutes,
      focusMinutes: usageSummary.focusMinutes,
      changePercentage: usageSummary.changePercentageFromYesterday,
      topCategory: topCategory,
      goalsCompletedCount: goalsCompleted,
      goalsTotalCount: goalsTotal,
      activeTriggerAlerts: activeAlerts,
      reportDateFormatted: reportDateFormatted,
    );
  }
}
