import '../../data/models/approved_report_model.dart';
import '../../data/models/child_profile_model.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/llm_models.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/reflection_model.dart';
import '../../data/models/usage_models.dart';
import '../analytics/report_comparison_service.dart';

/// ParentAIContextBuilder builds rich, full-workflow context for Parent AI.
/// It tracks real-world missions, daily usage, focus time, goals, reflections,
/// and approved reports to answer any parent question with grounded app facts.
class ParentAIContextBuilder {
  final String version;

  const ParentAIContextBuilder({this.version = '2.0.0'});

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

  /// Builds full workflow context across all features: Real-World Missions,
  /// Usage & Screen Time, Wellbeing Goals, Daily Reflection, and Activity ideas.
  String buildFullWorkflowPromptContext({
    required ChildProfile child,
    required List<ChildMission> missions,
    required List<ChildGoal> goals,
    UsageSummary? todayUsage,
    UsageSummary? yesterdayUsage,
    DailyReflection? todayReflection,
    List<ApprovedReport> reports = const [],
    String? customQuery,
  }) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    buffer.writeln('=== ClearTime App Workflow Context ===');
    buffer.writeln('- Child Profile: ${child.nickname} (Age: ${child.age})');

    // 1. REAL-WORLD MISSIONS / ACTIVITIES WORKFLOW
    final completedMissions =
        missions.where((m) => m.status == MissionStatus.approved).toList();
    final yesterdayCompleted = completedMissions.where((m) {
      final date = m.approvedAt ?? m.submittedAt;
      if (date == null) return false;
      return date.isAfter(yesterdayStart) && date.isBefore(todayStart);
    }).toList();

    // Fallback: If no explicit yesterday timestamp, look at recently completed missions
    final completedYesterdayOrRecent = yesterdayCompleted.isNotEmpty
        ? yesterdayCompleted
        : completedMissions.take(3).toList();

    final todayCompleted = completedMissions.where((m) {
      final date = m.approvedAt ?? m.submittedAt;
      if (date == null) return false;
      return date.isAfter(todayStart);
    }).toList();

    final activeMissions = missions
        .where((m) =>
            m.status == MissionStatus.assigned ||
            m.status == MissionStatus.started)
        .toList();
    final pendingMissions = missions
        .where((m) => m.status == MissionStatus.submitted)
        .toList();

    buffer.writeln('\n=== REAL-WORLD MISSIONS & ACTIVITIES HISTORY ===');
    buffer.writeln('- Total Completed Activities: ${completedMissions.length}');

    if (completedYesterdayOrRecent.isNotEmpty) {
      buffer.writeln('- Activities Completed Yesterday / Recently:');
      for (final m in completedYesterdayOrRecent) {
        final rewardStr = m.reward != null ? ' (Reward: ${m.reward})' : '';
        buffer.writeln(
            '  * "${m.title}" - ${m.targetMinutes} mins: ${m.description}$rewardStr');
      }
    } else {
      buffer.writeln('- Activities Completed Yesterday: None recorded yet.');
    }

    if (todayCompleted.isNotEmpty) {
      buffer.writeln('- Activities Completed Today:');
      for (final m in todayCompleted) {
        buffer.writeln('  * "${m.title}" - ${m.targetMinutes} mins');
      }
    }

    if (activeMissions.isNotEmpty) {
      buffer.writeln('- Currently In Progress / Assigned Activities:');
      for (final m in activeMissions) {
        buffer.writeln(
            '  * "${m.title}" (${m.targetMinutes}m) [Status: ${m.status.name}]');
      }
    }

    if (pendingMissions.isNotEmpty) {
      buffer.writeln(
          '- Pending Review (Child submitted proof awaiting parent approval):');
      for (final m in pendingMissions) {
        final notes = m.submissionNotes != null ? ' - Note: "${m.submissionNotes}"' : '';
        buffer.writeln('  * "${m.title}"$notes');
      }
    }

    // 2. DAILY USAGE & SCREEN TIME METRICS
    buffer.writeln('\n=== SCREEN TIME & HABIT METRICS ===');
    if (todayUsage != null) {
      buffer.writeln(
          '- Today Screen Time: ${todayUsage.totalMinutes ~/ 60}h ${todayUsage.totalMinutes % 60}m (${todayUsage.totalMinutes} minutes)');
      buffer.writeln(
          '- Today Focused Learning: ${todayUsage.focusMinutes ~/ 60}h ${todayUsage.focusMinutes % 60}m (${todayUsage.focusMinutes} minutes)');
      buffer.writeln(
          '- Mindful Movement Breaks Taken: ${todayUsage.breakCount}');
      if (todayUsage.categories.isNotEmpty) {
        buffer.writeln(
            '- Top App Categories Today: ${todayUsage.categories.take(3).map((c) => "${c.category} (${c.totalMinutes}m)").join(", ")}');
      }
    } else {
      buffer.writeln('- Today Screen Time: Healthy / Under baseline');
    }

    if (yesterdayUsage != null) {
      buffer.writeln(
          '- Yesterday Screen Time: ${yesterdayUsage.totalMinutes ~/ 60}h ${yesterdayUsage.totalMinutes % 60}m');
      buffer.writeln(
          '- Yesterday Focus Time: ${yesterdayUsage.focusMinutes ~/ 60}h ${yesterdayUsage.focusMinutes % 60}m');
    }

    // 3. WELLBEING GOALS
    buffer.writeln('\n=== WELLBEING GOALS ===');
    if (goals.isNotEmpty) {
      for (final g in goals) {
        buffer.writeln(
            '- Goal "${g.title}": ${g.targetMinutes}m target [Status: ${g.status.name}]');
      }
    } else {
      buffer.writeln('- Active Focus Goals: Daily 30m screen balance');
    }

    // 4. CHILD REFLECTION & MOOD
    if (todayReflection != null) {
      buffer.writeln('\n=== CHILD DAILY REFLECTION ===');
      buffer.writeln(
          '- Mood / Feeling: ${todayReflection.mood.label} ${todayReflection.mood.emoji}');
      if (todayReflection.notes != null && todayReflection.notes!.isNotEmpty) {
        buffer.writeln('- Reflection Note: "${todayReflection.notes}"');
      }
    }

    // 5. ClearTime App Feature Encyclopedia (for answering user questions about app features)
    buffer.writeln('\n=== ClearTime App Feature Knowledge Base ===');
    buffer.writeln('- 🏡 Parent-Assigned Real-World Missions: Offline activities, chores, and study tasks assigned directly by parents. Parents can require photo/note/timer proof and manually review/approve submissions.');
    buffer.writeln('- 🤖 AI-Assigned Autonomous Missions: Offline missions created dynamically by on-device AI based on live Android usage stats to counterbalance entertainment/gaming screen time.');
    buffer.writeln('- 📊 Mindful Reports & Summaries: Private on-device aggregation of weekly/daily trends, focus balance, and offline achievements.');
    buffer.writeln('- ⏱️ Downtime & Triggers: Configurable screen limits and mindful break triggers that encourage children to take eye and movement pauses.');
    buffer.writeln('- 🛡️ 100% On-Device AI Privacy: All AI inference runs locally on the phone (GGUF / Llama runtime). Zero telemetry or raw usage is sent to external servers.');

    // 6. INSTRUCTIONS TO LLM (DYNAMIC NON-STATIC REASONING)
    buffer.writeln('\n=== ASSISTANT INSTRUCTIONS ===');
    buffer.writeln(
        '1. You are ClearTime\'s On-Device Parent AI Assistant. You possess complete visibility into the child\'s real-world offline activities, screen time habits, wellbeing goals, and app capabilities.');
    buffer.writeln(
        '2. When the parent asks about app features (e.g. how missions work, what focus time is, how privacy works), explain clearly and concisely using the feature knowledge base.');
    buffer.writeln(
        '3. When the parent asks what tasks their child did yesterday or today, answer directly citing the actual completed activities from the history.');
    buffer.writeln(
        '4. When the parent asks "how to improve", "how to balance screen time", or requests suggestions, dynamically synthesize actionable, compassionate, and age-appropriate parenting advice and offline activity ideas based on today\'s specific screen time numbers.');
    buffer.writeln(
        '5. Maintain a warm, encouraging, conversational tone that empowers parents to nurture healthy digital habits with their children.');
    buffer.writeln(
        '6. Format responses cleanly with bold key points and bullet lists.');

    if (customQuery != null && customQuery.trim().isNotEmpty) {
      buffer.writeln('\n=== PARENT QUESTION ===');
      buffer.writeln(customQuery.trim());
    }

    return buffer.toString();
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
      buffer.writeln(
          '- Previous Period Screen Time: ${facts.previousScreenMinutes ~/ 60}h ${facts.previousScreenMinutes % 60}m');
      buffer.writeln(
          '- Change from Prior Period: ${facts.changePercentage >= 0 ? "+" : ""}${facts.changePercentage.toStringAsFixed(1)}%');
    }
    buffer.writeln(
        '- Focus & Learning Time: ${facts.formattedFocusTime} (${facts.focusMinutes} minutes)');
    buffer.writeln('- Mindful Movement Breaks: ${facts.breakCount} breaks recorded');
    if (facts.goalsTotalCount > 0) {
      buffer.writeln(
          '- Wellbeing Goals: ${facts.goalsCompletedCount} of ${facts.goalsTotalCount} completed');
    }
    if (facts.achievementsUnlocked.isNotEmpty) {
      buffer.writeln(
          '- Unlocked Milestones: ${facts.achievementsUnlocked.join(", ")}');
    }
    if (facts.categoryBreakdown.isNotEmpty) {
      buffer.writeln('- Category Breakdown:');
      facts.categoryBreakdown.forEach((cat, min) {
        buffer.writeln('  * $cat: ${min ~/ 60}h ${min % 60}m ($min min)');
      });
    }
    buffer.writeln('=== DETERMINISTIC REPORT SUMMARY ===');
    buffer.writeln(report.summaryText);

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
    buffer.writeln(
        '- Screen Time Change: ${comparison.screenTimeDiffFormatted} (${comparison.screenTimeChangePct >= 0 ? "+" : ""}${comparison.screenTimeChangePct}%)');
    buffer.writeln(
        '- Focus Time Change: ${comparison.focusTimeDiffFormatted} (${comparison.focusTimeChangePct >= 0 ? "+" : ""}${comparison.focusTimeChangePct}%)');
    buffer.writeln(
        '- Movement Breaks Change: ${comparison.breakDiff >= 0 ? "+" : ""}${comparison.breakDiff} breaks');
    buffer.writeln('- Overall Trend: ${comparison.overallTrendDirection}');
    buffer.writeln('=== DETERMINISTIC COMPARISON SUMMARY ===');
    buffer.writeln(comparison.deterministicSummary);

    buffer.writeln('=== PRE-COMPUTED EVIDENCE ITEMS ===');
    for (final ev in comparison.evidence) {
      buffer.writeln(
          '- ${ev.metric}: Current=${ev.currentValue}, Previous=${ev.previousValue}, Change=${ev.change}');
    }

    if (customQuery != null && customQuery.trim().isNotEmpty) {
      buffer.writeln('=== PARENT QUESTION ===');
      buffer.writeln(customQuery.trim());
    }

    return buffer.toString();
  }
}
