import '../../data/models/approved_report_model.dart';

/// Result of deterministic comparison between approved reports.
class ReportComparisonResult {
  final ApprovedReport currentReport;
  final ApprovedReport? previousReport;
  final List<ApprovedReport> allComparedReports;
  final List<AIEvidence> evidence;
  final String deterministicSummary;
  final String screenTimeDiffFormatted;
  final double screenTimeChangePct;
  final String focusTimeDiffFormatted;
  final double focusTimeChangePct;
  final int breakDiff;
  final int goalDiff;
  final String overallTrendDirection; // 'improving', 'increasing_screen_time', 'stable'

  const ReportComparisonResult({
    required this.currentReport,
    this.previousReport,
    this.allComparedReports = const [],
    this.evidence = const [],
    required this.deterministicSummary,
    required this.screenTimeDiffFormatted,
    required this.screenTimeChangePct,
    required this.focusTimeDiffFormatted,
    required this.focusTimeChangePct,
    required this.breakDiff,
    required this.goalDiff,
    required this.overallTrendDirection,
  });
}

/// ReportComparisonService computes 100% deterministic comparison facts
/// before any LLM prompt is assembled.
///
/// AI SAFETY PRINCIPLE:
/// The local LLM never invents comparison numbers; it explains these pre-computed metrics.
class ReportComparisonService {
  const ReportComparisonService();

  /// Compares current approved report against a previous approved report.
  ReportComparisonResult comparePair({
    required ApprovedReport current,
    required ApprovedReport previous,
  }) {
    final curFacts = current.facts;
    final prevFacts = previous.facts;

    final screenDiffMin = curFacts.totalScreenMinutes - prevFacts.totalScreenMinutes;
    final screenChangePct = prevFacts.totalScreenMinutes > 0
        ? ((screenDiffMin / prevFacts.totalScreenMinutes) * 100.0)
        : 0.0;

    final focusDiffMin = curFacts.focusMinutes - prevFacts.focusMinutes;
    final focusChangePct = prevFacts.focusMinutes > 0
        ? ((focusDiffMin / prevFacts.focusMinutes) * 100.0)
        : 0.0;

    final breakDiff = curFacts.breakCount - prevFacts.breakCount;
    final goalDiff = curFacts.goalsCompletedCount - prevFacts.goalsCompletedCount;

    final screenSign = screenChangePct >= 0 ? '+' : '';
    final focusSign = focusChangePct >= 0 ? '+' : '';
    final breakSign = breakDiff >= 0 ? '+' : '';

    final evidenceList = <AIEvidence>[
      AIEvidence(
        metric: 'Screen Time',
        currentValue: curFacts.formattedTotalTime,
        previousValue: prevFacts.formattedTotalTime,
        change: '$screenSign${screenChangePct.toStringAsFixed(1)}%',
        sourceReportId: current.id,
      ),
      AIEvidence(
        metric: 'Focus Time',
        currentValue: curFacts.formattedFocusTime,
        previousValue: prevFacts.formattedFocusTime,
        change: '$focusSign${focusChangePct.toStringAsFixed(1)}%',
        sourceReportId: current.id,
      ),
      AIEvidence(
        metric: 'Mindful Breaks',
        currentValue: '${curFacts.breakCount} breaks',
        previousValue: '${prevFacts.breakCount} breaks',
        change: '$breakSign$breakDiff breaks',
        sourceReportId: current.id,
      ),
      AIEvidence(
        metric: 'Goals Met',
        currentValue: '${curFacts.goalsCompletedCount}/${curFacts.goalsTotalCount}',
        previousValue: '${prevFacts.goalsCompletedCount}/${prevFacts.goalsTotalCount}',
        change: '${goalDiff >= 0 ? "+" : ""}$goalDiff goals',
        sourceReportId: current.id,
      ),
    ];

    String trend = 'stable';
    if (focusDiffMin > 10 || (screenDiffMin < -15 && curFacts.breakCount >= 3)) {
      trend = 'improving';
    } else if (screenDiffMin > 30 && focusDiffMin <= 0) {
      trend = 'increasing_screen_time';
    }

    final summary = StringBuffer();
    summary.write('Comparing ${current.formattedPeriodTitle} with ${previous.formattedPeriodTitle}: ');
    summary.write('Screen time changed by $screenSign${screenChangePct.toStringAsFixed(1)}% (${curFacts.formattedTotalTime} vs ${prevFacts.formattedTotalTime}). ');
    summary.write('Focus time changed by $focusSign${focusChangePct.toStringAsFixed(1)}% (${curFacts.formattedFocusTime} vs ${prevFacts.formattedFocusTime}). ');
    if (breakDiff != 0) {
      summary.write('Movement breaks changed by $breakSign$breakDiff. ');
    }

    return ReportComparisonResult(
      currentReport: current,
      previousReport: previous,
      allComparedReports: [previous, current],
      evidence: evidenceList,
      deterministicSummary: summary.toString(),
      screenTimeDiffFormatted: '$screenSign${screenDiffMin.abs()}m',
      screenTimeChangePct: double.parse(screenChangePct.toStringAsFixed(1)),
      focusTimeDiffFormatted: '$focusSign${focusDiffMin.abs()}m',
      focusTimeChangePct: double.parse(focusChangePct.toStringAsFixed(1)),
      breakDiff: breakDiff,
      goalDiff: goalDiff,
      overallTrendDirection: trend,
    );
  }

  /// Compares a sequence of historical reports (e.g. 4 consecutive weeks).
  ReportComparisonResult compareSeries(List<ApprovedReport> reports) {
    if (reports.isEmpty) {
      throw ArgumentError('Cannot compare empty report list');
    }
    if (reports.length == 1) {
      final r = reports.first;
      return ReportComparisonResult(
        currentReport: r,
        allComparedReports: reports,
        evidence: const [],
        deterministicSummary: 'Single report snapshot: ${r.summaryText}',
        screenTimeDiffFormatted: '0m',
        screenTimeChangePct: 0.0,
        focusTimeDiffFormatted: '0m',
        focusTimeChangePct: 0.0,
        breakDiff: 0,
        goalDiff: 0,
        overallTrendDirection: 'stable',
      );
    }

    final sorted = List<ApprovedReport>.from(reports)
      ..sort((a, b) => a.periodStart.compareTo(b.periodStart));

    final first = sorted.first;
    final latest = sorted.last;

    return comparePair(current: latest, previous: first);
  }
}
