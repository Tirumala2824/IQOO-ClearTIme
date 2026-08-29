import '../../data/models/approved_report_model.dart';
import '../../data/models/llm_models.dart';
import '../../data/models/usage_models.dart';
import '../analytics/report_comparison_service.dart';

/// ParentAIContextBuilder builds strictly approved parent report context.
///
/// CRITICAL PRIVACY INVARIANT:
/// 1. Raw child device timestamps are filtered out.
/// 2. Raw private child reflections are never exposed.
/// 3. Hidden device status and background logs are never included.
/// 4. Only parent-approved aggregated summaries enter the prompt.
/// 5. Enforces strict multi-child isolation.
class ParentAIContextBuilder {
  final String version;

  const ParentAIContextBuilder({this.version = '1.0.0'});

  /// Builds a sanitized parent report context from today's usage summary (Phase 3 compatibility).
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

  /// Builds a structured prompt context from a formal ApprovedReport entity.
  String buildReportPromptContext({
    required ApprovedReport report,
    String? customQuery,
  }) {
    final buffer = StringBuffer();
    final facts = report.facts;

    buffer.writeln('=== APPROVED PARENT REPORT FACTS ===');
    buffer.writeln('- Child: ${report.childNickname} (Child ID: ${report.childId})');
    buffer.writeln('- Report Period: ${report.formattedPeriodTitle}');
    buffer.writeln('- Detail Level: ${report.detailLevel.label}');
    buffer.writeln('- Context Version: ${report.contextVersion}');
    buffer.writeln('- Total Screen Time: ${facts.formattedTotalTime} (${facts.totalScreenMinutes} minutes)');
    if (facts.previousScreenMinutes > 0) {
      buffer.writeln('- Previous Period Screen Time: ${facts.previousScreenMinutes ~/ 60}h ${facts.previousScreenMinutes % 60}m');
      buffer.writeln('- Change from Prior Period: ${facts.changePercentage >= 0 ? "+" : ""}${facts.changePercentage.toStringAsFixed(1)}%');
    }
    buffer.writeln('- Focus & Learning Time: ${facts.formattedFocusTime} (${facts.focusMinutes} minutes)');
    buffer.writeln('- Mindful Movement Breaks: ${facts.breakCount} breaks recorded');
    if (facts.goalsTotalCount > 0) {
      buffer.writeln('- Wellbeing Goals: ${facts.goalsCompletedCount} of ${facts.goalsTotalCount} completed');
    }
    if (facts.achievementsUnlocked.isNotEmpty) {
      buffer.writeln('- Unlocked Milestones: ${facts.achievementsUnlocked.join(", ")}');
    }
    if (facts.categoryBreakdown.isNotEmpty) {
      buffer.writeln('- Category Breakdown:');
      facts.categoryBreakdown.forEach((cat, min) {
        buffer.writeln('  * $cat: ${min ~/ 60}h ${min % 60}m ($min min)');
      });
    }
    buffer.writeln('=== DETERMINISTIC REPORT SUMMARY ===');
    buffer.writeln(report.summaryText);
    buffer.writeln('=== STRICT AI PRIVACY & SAFETY INSTRUCTIONS ===');
    buffer.writeln('1. Base ALL observations strictly on the approved facts listed above.');
    buffer.writeln('2. Never invent numbers, app names, exact timestamps, or device telemetry.');
    buffer.writeln('3. Clearly separate FACT, INFERENCE, and SUGGESTION in your response.');
    buffer.writeln('4. If the parent asks about raw timestamps, specific app names, hidden child reflections, or information not present above, explicitly reply: "That information isn\'t available in the approved wellbeing report."');
    buffer.writeln('5. Never claim to have accessed the child device directly or bypassed privacy boundaries.');

    if (customQuery != null && customQuery.trim().isNotEmpty) {
      buffer.writeln('=== PARENT INQUIRY ===');
      buffer.writeln(customQuery.trim());
    }

    return buffer.toString();
  }

  /// Builds context for deterministic report comparison.
  String buildComparisonPromptContext({
    required ReportComparisonResult comparison,
    String? customQuery,
  }) {
    final buffer = StringBuffer();
    final cur = comparison.currentReport;
    final prev = comparison.previousReport;

    buffer.writeln('=== APPROVED REPORT COMPARISON FACTS ===');
    buffer.writeln('- Child: ${cur.childNickname}');
    buffer.writeln('- Current Period: ${cur.formattedPeriodTitle}');
    if (prev != null) {
      buffer.writeln('- Previous Period: ${prev.formattedPeriodTitle}');
    }
    buffer.writeln('- Screen Time Change: ${comparison.screenTimeDiffFormatted} (${comparison.screenTimeChangePct >= 0 ? "+" : ""}${comparison.screenTimeChangePct}%)');
    buffer.writeln('- Focus Time Change: ${comparison.focusTimeDiffFormatted} (${comparison.focusTimeChangePct >= 0 ? "+" : ""}${comparison.focusTimeChangePct}%)');
    buffer.writeln('- Movement Breaks Change: ${comparison.breakDiff >= 0 ? "+" : ""}${comparison.breakDiff} breaks');
    buffer.writeln('- Overall Trend: ${comparison.overallTrendDirection}');
    buffer.writeln('=== DETERMINISTIC COMPARISON SUMMARY ===');
    buffer.writeln(comparison.deterministicSummary);

    buffer.writeln('=== PRE-COMPUTED EVIDENCE ITEMS ===');
    for (final ev in comparison.evidence) {
      buffer.writeln('- ${ev.metric}: Current=${ev.currentValue}, Previous=${ev.previousValue}, Change=${ev.change}');
    }

    buffer.writeln('=== STRICT INSTRUCTIONS ===');
    buffer.writeln('1. Use only the pre-computed comparison metrics.');
    buffer.writeln('2. Explain why changes may have occurred in positive, encouraging terms.');
    buffer.writeln('3. Separate FACT from SUGGESTION.');
    buffer.writeln('4. If asked for unrecorded details, note that granular device logs are not stored.');

    if (customQuery != null && customQuery.trim().isNotEmpty) {
      buffer.writeln('=== PARENT QUESTION ===');
      buffer.writeln(customQuery.trim());
    }

    return buffer.toString();
  }
}
