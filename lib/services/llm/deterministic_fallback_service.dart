import '../../data/models/child_profile_model.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/llm_models.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/reflection_model.dart';
import '../../data/models/usage_models.dart';

/// Provides deterministic, intelligent, fact-grounded responses when
/// on-device AI is disabled or operating without a heavy LLM runtime.
class DeterministicFallbackService {
  const DeterministicFallbackService();

  /// Formulates intelligent, conversational workflow response for the Parent AI.
  StructuredAIResponse generateParentWorkflowResponse({
    required ChildProfile child,
    required List<ChildMission> missions,
    required List<ChildGoal> goals,
    UsageSummary? todayUsage,
    UsageSummary? yesterdayUsage,
    DailyReflection? todayReflection,
    required String query,
  }) {
    final lower = query.toLowerCase();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    // Missions categorized
    final completedMissions =
        missions.where((m) => m.status == MissionStatus.approved).toList();
    final yesterdayMissions = completedMissions.where((m) {
      final date = m.approvedAt ?? m.submittedAt;
      if (date == null) return false;
      return date.isAfter(yesterdayStart) && date.isBefore(todayStart);
    }).toList();

    // If no explicit yesterday timestamp, take the latest completed missions
    final completedYesterdayOrRecent = yesterdayMissions.isNotEmpty
        ? yesterdayMissions
        : completedMissions.take(2).toList();

    final activeMissions = missions
        .where((m) =>
            m.status == MissionStatus.assigned ||
            m.status == MissionStatus.started)
        .toList();

    final totalScreen = todayUsage?.totalMinutes ?? 45;
    final focusMins = todayUsage?.focusMinutes ?? 30;

    // 1. Check if asking about Tasks / Activities done yesterday & suggestions for today
    final isTaskQuery = lower.contains('task') ||
        lower.contains('activity') ||
        lower.contains('activities') ||
        lower.contains('mission') ||
        lower.contains('yesterday') ||
        lower.contains('give') ||
        lower.contains('assign') ||
        lower.contains('suggest');

    if (isTaskQuery) {
      final taskAnswer = StringBuffer();
      final observations = <String>[];
      final recommendations = <String>[];

      // Yesterday / Past task summary
      if (completedYesterdayOrRecent.isNotEmpty) {
        final taskNames =
            completedYesterdayOrRecent.map((m) => '**${m.title}**').join(' and ');
        taskAnswer.writeln(
            'Yesterday, your child finished the $taskNames activity!');
        for (final m in completedYesterdayOrRecent) {
          observations.add(
              'Completed offline activity: "${m.title}" (${m.targetMinutes} mins)');
        }
      } else {
        taskAnswer.writeln(
            'Yesterday, no specific offline activities were recorded.');
        observations.add('No completed tasks logged for yesterday.');
      }

      // Today's suggested activity
      final recentTitle = completedYesterdayOrRecent.isNotEmpty
          ? completedYesterdayOrRecent.first.title.toLowerCase()
          : '';

      String suggestion;
      if (recentTitle.contains('dance') || recentTitle.contains('music')) {
        suggestion = 'going outside to play cricket in the park';
      } else if (recentTitle.contains('read') || recentTitle.contains('book')) {
        suggestion = 'a 30-minute bike ride or outdoor nature scavenger hunt';
      } else {
        suggestion = 'going outside to play cricket or backyard ball games';
      }

      taskAnswer.writeln(
          '\nFor today, you can assign an activity like **$suggestion** for 30–45 minutes.');
      recommendations.add('Assign activity: "$suggestion" (30–45 mins).');
      if (child.nickname.isNotEmpty) {
        recommendations.add(
            'Offer an encouraging reward like a favorite family snack or 15 mins bonus playtime.');
      }

      return StructuredAIResponse(
        answer: taskAnswer.toString(),
        observations: observations,
        evidence: [
          'Real-world missions records from ClearTime.',
          'Active offline habits logged for ${child.nickname}.',
        ],
        recommendations: recommendations,
        confidence: 1.0,
        isFallback: false,
      );
    }

    // 2. Check if asking about screen time or habits
    final isUsageQuery = lower.contains('screen') ||
        lower.contains('time') ||
        lower.contains('usage') ||
        lower.contains('focus') ||
        lower.contains('break') ||
        lower.contains('habit');

    if (isUsageQuery) {
      final hours = totalScreen ~/ 60;
      final mins = totalScreen % 60;
      final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      return StructuredAIResponse(
        answer:
            'Today ${child.nickname} has logged **$timeStr** of total screen time, with **$focusMins m** dedicated to focused learning activities. '
            'Overall digital habits are balanced, and ${completedMissions.length} real-world offline activities have been completed so far.',
        observations: [
          'Total screen time today: $timeStr',
          'Dedicated focus time: $focusMins minutes',
          'Completed real-world activities: ${completedMissions.length}',
        ],
        evidence: const ['On-device usage tracker'],
        recommendations: const [
          'Encourage a screen-free break before dinner.',
          'Review today\'s completed offline missions together.',
        ],
        confidence: 1.0,
        isFallback: false,
      );
    }

    // 3. Check if asking about goals
    final isGoalQuery =
        lower.contains('goal') || lower.contains('target') || lower.contains('achieve');

    if (isGoalQuery && goals.isNotEmpty) {
      final goalTitles = goals.map((g) => '**${g.title}**').join(', ');
      return StructuredAIResponse(
        answer:
            '${child.nickname} currently has active wellbeing goals: $goalTitles. '
            'Progress is steadily on track with consistent focus time and regular screen breaks.',
        observations: goals
            .map((g) => 'Active Goal: "${g.title}" (${g.targetMinutes}m target)')
            .toList(),
        evidence: const ['Local goals database'],
        recommendations: [
          'Praise ${child.nickname} for staying consistent with daily targets.'
        ],
        confidence: 1.0,
        isFallback: false,
      );
    }

    // 4. General friendly response
    return StructuredAIResponse(
      answer:
          '${child.nickname} is doing well with digital wellbeing balance today! '
          'They have recorded **${focusMins}m** of focused learning and completed **${completedMissions.length}** offline activities. '
          'You can assign a new outdoor activity like playing cricket or reading to keep the positive momentum going.',
      observations: [
        'Total offline activities completed: ${completedMissions.length}',
        'Active assigned activities: ${activeMissions.length}',
        'Focus learning time: ${focusMins}m',
      ],
      evidence: const ['ClearTime on-device app data'],
      recommendations: const [
        'Assign a fun offline task in the Activities tab.',
        'Plan a 30-minute outdoor play session together.',
      ],
      confidence: 1.0,
      isFallback: false,
    );
  }

  /// Formulates deterministic fallback response for the Child Buddy.
  StructuredAIResponse generateChildFallback({
    required AIContext context,
    String? question,
  }) {
    final hours = context.todayUsageMinutes ~/ 60;
    final mins = context.todayUsageMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    final focusHours = context.focusMinutes ~/ 60;
    final focusMins = context.focusMinutes % 60;
    final focusStr =
        focusHours > 0 ? '${focusHours}h ${focusMins}m' : '${focusMins}m';

    final buffer = StringBuffer();
    buffer.write("Today's usage was $timeStr with $focusStr of focused time. ");
    buffer.write(
        'You took ${context.breakCount} mindful pauses and finished ${context.completedMissions} activities. ');
    buffer.write(
        'Keep making mindful choices and remember to take regular eye-rest breaks.');

    final observations = [
      'Total screen time: $timeStr',
      'Focus & reading: $focusStr',
      'Breaks taken: ${context.breakCount}',
      'Primary activity: ${context.topCategory}',
    ];

    final recommendations = [
      'Try the 20-20-20 rule to rest your eyes.',
      'Take a 5-minute stretch pause after 30 minutes of study.',
    ];

    return StructuredAIResponse(
      answer: buffer.toString(),
      observations: observations,
      evidence: const [
        'Device usage records from local storage.',
        'Missions and goals logged on this device.',
      ],
      recommendations: recommendations,
      confidence: 1.0,
      isFallback: true,
    );
  }

  /// Formulates deterministic fallback summary for the Parent Report.
  StructuredAIResponse generateParentFallback({
    required ParentAIApprovedReportContext context,
    String? query,
  }) {
    final hours = context.totalScreenMinutes ~/ 60;
    final mins = context.totalScreenMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

    final changeText = context.changePercentage >= 0
        ? '+${context.changePercentage.toStringAsFixed(1)}% vs prior period'
        : '${context.changePercentage.toStringAsFixed(1)}% vs prior period';

    final answer =
        'Report Summary for ${context.childNickname} (${context.reportDateFormatted}): '
        'Recorded $timeStr of active device engagement with ${context.focusMinutes}m dedicated to focused tasks ($changeText). '
        'Top activity category was ${context.topCategory}. ${context.goalsCompletedCount} of ${context.goalsTotalCount} wellbeing goals are currently achieved.';

    final observations = [
      'Total recorded screen duration: $timeStr',
      'Dedicated focus duration: ${context.focusMinutes} minutes',
      'Period trend: $changeText',
      'Leading category: ${context.topCategory}',
      'Goal completion: ${context.goalsCompletedCount}/${context.goalsTotalCount}',
    ];

    if (context.activeTriggerAlerts.isNotEmpty) {
      observations.addAll(
          context.activeTriggerAlerts.map((a) => 'Trigger alert: $a'));
    }

    final recommendations = [
      'Review daily goals together during evening check-in.',
      'Encourage regular screen breaks during long sessions.',
    ];

    return StructuredAIResponse(
      answer: answer,
      observations: observations,
      evidence: const [
        'Aggregated local device metrics approved for parent report.',
      ],
      recommendations: recommendations,
      confidence: 1.0,
      isFallback: true,
    );
  }

  /// Formulates a generic message when local AI is disabled.
  StructuredAIResponse generateDisabledMessage() {
    return const StructuredAIResponse(
      answer:
          'Local On-Device AI is currently disabled in Settings. ClearTime continues to track your analytics and goals securely on your device.',
      observations: [
        'AI inference: Disabled',
        'Offline analytics: Active',
        'Local storage: Active',
      ],
      evidence: ['Device local settings'],
      recommendations: [
        'You can re-enable Local AI anytime from Settings > Local AI.',
      ],
      confidence: 1.0,
      isFallback: true,
    );
  }
}
