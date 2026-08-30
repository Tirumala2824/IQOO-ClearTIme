import '../../data/models/llm_models.dart';

/// Provides deterministic, fact-grounded summaries when on-device AI is disabled or unavailable.
///
/// STRICT INVARIANT:
/// Never calls any external network service.
/// All output is generated using deterministic Dart string formatting and local usage facts.
class DeterministicFallbackService {
  const DeterministicFallbackService();

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
      evidence: [
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
      evidence: [
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
