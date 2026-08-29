import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/services/analytics/report_comparison_service.dart';

void main() {
  group('ReportComparisonService Unit Tests', () {
    const service = ReportComparisonService();
    final now = DateTime(2026, 8, 29);

    final currentWeekly = ApprovedReport(
      id: 'rep-cur',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: now.subtract(const Duration(days: 7)),
      periodEnd: now,
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
      ),
      summaryText: 'Current week summary',
      createdAt: now,
    );

    final previousWeekly = ApprovedReport(
      id: 'rep-prev',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: now.subtract(const Duration(days: 14)),
      periodEnd: now.subtract(const Duration(days: 7)),
      facts: const ReportFacts(
        totalScreenMinutes: 778, // 12h 58m
        focusMinutes: 320, // 5h 20m
        breakCount: 18,
        goalsCompletedCount: 4,
        goalsTotalCount: 6,
      ),
      summaryText: 'Previous week summary',
      createdAt: now.subtract(const Duration(days: 7)),
    );

    test('comparePair computes exact deterministic differences and structured evidence', () {
      final result = service.comparePair(
        current: currentWeekly,
        previous: previousWeekly,
      );

      expect(result.screenTimeChangePct, equals(12.1));
      expect(result.focusTimeChangePct, equals(15.6));
      expect(result.breakDiff, equals(4));
      expect(result.goalDiff, equals(1));
      expect(result.evidence.length, equals(4));

      final screenEvidence =
          result.evidence.firstWhere((e) => e.metric == 'Screen Time');
      expect(screenEvidence.currentValue, equals('14h 32m'));
      expect(screenEvidence.previousValue, equals('12h 58m'));
      expect(screenEvidence.change, equals('+12.1%'));

      final focusEvidence =
          result.evidence.firstWhere((e) => e.metric == 'Focus Time');
      expect(focusEvidence.currentValue, equals('6h 10m'));
      expect(focusEvidence.previousValue, equals('5h 20m'));
      expect(focusEvidence.change, equals('+15.6%'));

      expect(result.deterministicSummary, contains('Screen time changed by +12.1%'));
    });

    test('compareSeries handles multi-report sequence', () {
      final reports = [previousWeekly, currentWeekly];
      final result = service.compareSeries(reports);

      expect(result.currentReport.id, equals('rep-cur'));
      expect(result.previousReport?.id, equals('rep-prev'));
      expect(result.screenTimeChangePct, equals(12.1));
    });
  });
}
