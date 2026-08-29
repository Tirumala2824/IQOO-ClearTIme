import '../../data/models/llm_models.dart';
import '../../data/models/usage_models.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/reflection_model.dart';

/// LocalAIContextBuilder aggregates strictly structured analytical facts
/// to build prompt context for the on-device AI model.
///
/// CRITICAL PRIVACY RULE:
/// Raw timestamps, logs, and package names are filtered out.
/// Only structured, non-identifying wellbeing facts enter the AI context.
class LocalAIContextBuilder {
  const LocalAIContextBuilder();

  /// Builds a sanitized, structured facts context for the on-device LLM.
  AIContext buildContext({
    required UsageSummary usageSummary,
    required List<ChildMission> missions,
    required List<ChildGoal> goals,
    DailyReflection? reflection,
  }) {
    final topCategory = usageSummary.categories.isNotEmpty
        ? usageSummary.categories.first.category
        : 'General Learning';

    final completedMissionsCount =
        missions.where((m) => m.isCompleted).length;

    final activeGoalsCount =
        goals.where((g) => g.status == GoalStatus.active).length;

    String? reflectionText;
    if (reflection != null) {
      reflectionText =
          'Felt ${reflection.mood.label}${reflection.notes != null ? ": ${reflection.notes}" : ""}';
    }

    return AIContext(
      todayUsageMinutes: usageSummary.totalMinutes,
      focusMinutes: usageSummary.focusMinutes,
      breakCount: usageSummary.breakCount,
      usageChangePercentage: usageSummary.changePercentageFromYesterday,
      topCategory: topCategory,
      completedMissions: completedMissionsCount,
      activeGoalsCount: activeGoalsCount,
      recentReflection: reflectionText,
    );
  }
}
