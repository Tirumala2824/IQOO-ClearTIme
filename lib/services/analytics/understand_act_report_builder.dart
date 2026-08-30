import '../../data/models/usage_models.dart';

/// Understand → Act report sections.
///
/// Every report carries exactly four sections:
///  * at_a_glance  — approved aggregate totals only;
///  * what_changed  — comparison with the preceding equivalent period;
///  * what_it_may_mean — clearly marked local-AI interpretation grounded in
///    those facts (or an honest "no interpretation available" note);
///  * next_steps — two or three practical, non-punitive suggestions.
class UnderstandActSections {
  final String atAGlance;
  final String whatChanged;
  final String whatItMayMean;
  final bool interpretationIsAiGenerated;
  final List<String> nextSteps;

  const UnderstandActSections({
    required this.atAGlance,
    required this.whatChanged,
    required this.whatItMayMean,
    required this.interpretationIsAiGenerated,
    required this.nextSteps,
  });

  Map<String, dynamic> toJson() => {
        'at_a_glance': atAGlance,
        'what_changed': whatChanged,
        'what_it_may_mean': whatItMayMean,
        'interpretation_is_ai_generated': interpretationIsAiGenerated,
        'next_steps': nextSteps,
      };

  factory UnderstandActSections.fromJson(Map<String, dynamic> json) =>
      UnderstandActSections(
        atAGlance: json['at_a_glance'] as String? ?? '',
        whatChanged: json['what_changed'] as String? ?? '',
        whatItMayMean: json['what_it_may_mean'] as String? ?? '',
        interpretationIsAiGenerated:
            json['interpretation_is_ai_generated'] as bool? ?? false,
        nextSteps: List<String>.from(json['next_steps'] as List? ?? []),
      );
}

/// Builds the Understand → Act narrative strictly from locally stored daily
/// aggregates. No value is fabricated: every number comes from
/// [DailyAggregate] records collected by the platform usage API.
class UnderstandActReportBuilder {
  const UnderstandActReportBuilder();

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  UnderstandActSections build({
    required List<DailyAggregate> current,
    required List<DailyAggregate> previous,
    required String? localAiInterpretation,
  }) {    final total = current.fold<int>(0, (s, a) => s + a.totalMinutes);
    final focus = current.fold<int>(0, (s, a) => s + a.focusMinutes);
    final breaks = current.fold<int>(0, (s, a) => s + a.breakCount);

    final prevTotal = previous.fold<int>(0, (s, a) => s + a.totalMinutes);
    final prevFocus = previous.fold<int>(0, (s, a) => s + a.focusMinutes);

    final String changed;
    if (previous.isEmpty) {
      changed =
          'There is no earlier period recorded on this device yet, so no '
          'comparison is shown.';
    } else {
      final totalDelta = total - prevTotal;
      final focusDelta = focus - prevFocus;
      final totalTxt = totalDelta == 0
          ? 'the same as before'
          : totalDelta > 0
              ? 'up ${_fmt(totalDelta)}'
              : 'down ${_fmt(-totalDelta)}';
      final focusTxt = focusDelta == 0
          ? 'the same as before'
          : focusDelta > 0
              ? 'up ${_fmt(focusDelta)}'
              : 'down ${_fmt(-focusDelta)}';
      changed =
          'Total device time is $totalTxt and focused time is $focusTxt '
          'compared with the previous period.';
    }

    final interpretation = (localAiInterpretation == null ||
            localAiInterpretation.trim().isEmpty)
        ? 'No local interpretation is available for this report.'
        : localAiInterpretation.trim();

    return UnderstandActSections(
      atAGlance:
          '${_fmt(total)} total device time, ${_fmt(focus)} focused time, '
          'and $breaks breaks across ${current.length} '
          '${current.length == 1 ? 'day' : 'days'}.',
      whatChanged: changed,
      whatItMayMean: interpretation,
      interpretationIsAiGenerated: localAiInterpretation != null &&
          localAiInterpretation.trim().isNotEmpty,
      nextSteps: _nextSteps(total, focus, breaks, current.length),
    );
  }

  List<String> _nextSteps(int total, int focus, int breaks, int days) {
    final steps = <String>[];
    if (breaks < days) {
      steps.add('Take a short screen-free break after every 30 minutes.');
    } else {
      steps.add('Keep up your break rhythm — short pauses help your eyes.');
    }
    if (focus > 0) {
      steps.add('You had ${_fmt(focus)} of focused time — build on that '
          'tomorrow with one distraction-free stretch.');
    } else {
      steps.add('Try a 15-minute focused stretch tomorrow, on anything you '
          'enjoy learning.');
    }
    return steps.take(3).toList();
  }
}