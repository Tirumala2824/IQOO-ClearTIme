import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/services/analytics/child_report_builder.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';

import '../helpers/encrypted_store_helper.dart';

void main() {
  group('ApprovedReport & ChildReportBuilder Unit Tests', () {
    late ChildReportBuilder builder;
    late ApprovedReportRepository reportRepo;

    setUp(() async {
      builder = const ChildReportBuilder();
      final store = await createTestDeviceStore();
      reportRepo = EncryptedApprovedReportRepository(store: store);
      await reportRepo.clearLocalCache();
    });

    test('buildDailyReport generates deterministic facts from daily analytics', () {
      final now = DateTime(2026, 8, 29);
      final daily = DailyUsage(
        date: now,
        totalMinutes: 120,
        focusMinutes: 45,
        unlockCount: 15,
        categoryMinutes: {'Learning': 45, 'Entertainment': 75},
      );
      final prevDaily = DailyUsage(
        date: now.subtract(const Duration(days: 1)),
        totalMinutes: 150,
        focusMinutes: 30,
      );

      final report = builder.buildDailyReport(
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'family-1',
        date: now,
        currentDaily: daily,
        previousDaily: prevDaily,
        focusMinutes: 45,
        previousFocusMinutes: 30,
        breakCount: 4,
        previousBreakCount: 2,
        goalsCompleted: 2,
        goalsTotal: 3,
        achievementsUnlockedCount: 1,
        unlockedBadgeTitles: ['Focus Starter'],
      );

      expect(report.childId, equals('child-1'));
      expect(report.childNickname, equals('Alex'));
      expect(report.period, equals(ReportPeriod.daily));
      expect(report.facts.totalScreenMinutes, equals(120));
      expect(report.facts.previousScreenMinutes, equals(150));
      expect(report.facts.changePercentage, equals(-20.0));
      expect(report.facts.focusMinutes, equals(45));
      expect(report.facts.focusChangePercentage, equals(50.0));
      expect(report.facts.breakCount, equals(4));
      expect(report.facts.goalsCompletedCount, equals(2));
      expect(report.facts.achievementsUnlocked, contains('Focus Starter'));
      expect(report.summaryText, contains('Alex spent 2h 0m on connected devices today'));
      expect(report.isSnapshot, isTrue);
    });

    test('buildWeeklyReport aggregates multiple daily records deterministically', () {
      final weekStart = DateTime(2026, 8, 22);
      final weekEnd = DateTime(2026, 8, 29);
      final days = List.generate(
        7,
        (i) => DailyUsage(
          date: weekStart.add(Duration(days: i)),
          totalMinutes: 100,
          focusMinutes: 30,
          categoryMinutes: {'Learning': 30, 'Entertainment': 70},
          unlockCount: 10,
        ),
      );

      final report = builder.buildWeeklyReport(
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'family-1',
        weekStart: weekStart,
        weekEnd: weekEnd,
        dailyUsages: days,
        totalFocusMinutes: 210,
        totalBreakCount: 14,
        goalsCompleted: 5,
        goalsTotal: 7,
      );

      expect(report.period, equals(ReportPeriod.weekly));
      expect(report.facts.totalScreenMinutes, equals(700));
      expect(report.facts.focusMinutes, equals(210));
      expect(report.facts.breakCount, equals(14));
      expect(report.facts.goalsCompletedCount, equals(5));
      expect(report.summaryText, contains('Alex spent 11h 40m on connected devices this week'));
    });

    test('buildMonthlyReport generates monthly aggregate snapshot', () {
      final report = builder.buildMonthlyReport(
        childId: 'child-2',
        childNickname: 'Maya',
        familyId: 'family-1',
        year: 2026,
        month: 8,
        totalMinutes: 2400, // 40h
        previousMonthMinutes: 2700,
        totalFocusMinutes: 900,
        totalBreakCount: 60,
        goalsCompleted: 20,
        goalsTotal: 25,
      );

      expect(report.period, equals(ReportPeriod.monthly));
      expect(report.facts.totalScreenMinutes, equals(2400));
      expect(report.facts.changePercentage, equals(-11.1));
      expect(report.facts.focusMinutes, equals(900));
    });

    test('buildApprovedSnapshot attaches Understand→Act sections', () {
      final report = builder.buildApprovedSnapshot(
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'family-1',
        period: ReportPeriod.weekly,
        periodStart: DateTime(2026, 8, 22),
        periodEnd: DateTime(2026, 8, 29),
        facts: const ReportFacts(
          totalScreenMinutes: 600,
          focusMinutes: 200,
          breakCount: 10,
        ),
        understandActSections: const {
          'at_a_glance': '10h total device time',
          'what_changed': 'up 2h',
          'what_it_may_mean': 'No local interpretation available.',
          'next_steps': ['Take a short break after 30 minutes.'],
        },
      );

      expect(report.isSnapshot, isTrue);
      expect(report.period, equals(ReportPeriod.weekly));
      expect(report.understandActSections['at_a_glance'],
          equals('10h total device time'));
      expect(report.facts.totalScreenMinutes, equals(600));

      final copied = report.copyWith(summaryText: 'Updated summary');
      expect(copied.summaryText, equals('Updated summary'));
      expect(copied.understandActSections, equals(report.understandActSections));
    });

    test('ApprovedReport JSON serialization and deserialization retains all fields', () {
      final now = DateTime(2026, 8, 29, 12, 0, 0);
      final report = ApprovedReport(
        id: 'rep-test-json',
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'family-1',
        period: ReportPeriod.weekly,
        periodStart: now.subtract(const Duration(days: 7)),
        periodEnd: now,
        detailLevel: ReportDetailLevel.detailed,
        facts: const ReportFacts(
          totalScreenMinutes: 600,
          focusMinutes: 200,
          breakCount: 10,
          categoryBreakdown: {'Learning': 200, 'Other': 400},
        ),
        summaryText: 'Weekly summary text',
        understandActSections: const {
          'at_a_glance': '10h total device time',
          'next_steps': ['Take a short break after 30 minutes.'],
        },
        createdAt: now,
        isSnapshot: true,
      );

      final json = report.toJson();
      final fromJson = ApprovedReport.fromJson(json);

      expect(fromJson.id, equals(report.id));
      expect(fromJson.childNickname, equals('Alex'));
      expect(fromJson.period, equals(ReportPeriod.weekly));
      expect(fromJson.facts.totalScreenMinutes, equals(600));
      expect(fromJson.facts.focusMinutes, equals(200));
      expect(fromJson.facts.breakCount, equals(10));
      expect(fromJson.facts.categoryBreakdown['Learning'], equals(200));
      expect(fromJson.understandActSections['at_a_glance'],
          equals('10h total device time'));
      expect(fromJson.understandActSections['next_steps'],
          contains('Take a short break after 30 minutes.'));
    });

    test('Multi-child isolation: Child A reports never leak under Child B query', () async {
      final now = DateTime.now();
      final reportA = ApprovedReport(
        id: 'rep-child-a',
        childId: 'child-a',
        childNickname: 'Child A',
        familyId: 'family-1',
        period: ReportPeriod.weekly,
        periodStart: now.subtract(const Duration(days: 7)),
        periodEnd: now,
        facts: const ReportFacts(totalScreenMinutes: 500, focusMinutes: 200, breakCount: 10),
        summaryText: 'Child A summary',
        createdAt: now,
      );

      final reportB = ApprovedReport(
        id: 'rep-child-b',
        childId: 'child-b',
        childNickname: 'Child B',
        familyId: 'family-1',
        period: ReportPeriod.weekly,
        periodStart: now.subtract(const Duration(days: 7)),
        periodEnd: now,
        facts: const ReportFacts(totalScreenMinutes: 300, focusMinutes: 100, breakCount: 5),
        summaryText: 'Child B summary',
        createdAt: now,
      );

      await reportRepo.saveApprovedReport(reportA);
      await reportRepo.saveApprovedReport(reportB);

      final fetchedA = await reportRepo.getApprovedReports('child-a');
      final fetchedB = await reportRepo.getApprovedReports('child-b');

      expect(fetchedA.length, equals(1));
      expect(fetchedA.first.childNickname, equals('Child A'));
      expect(fetchedB.length, equals(1));
      expect(fetchedB.first.childNickname, equals('Child B'));
    });
  });
}
