import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';
import 'package:cleartime/services/analytics/child_report_builder.dart';
import 'package:cleartime/services/analytics/local_analytics_service.dart';
import 'package:cleartime/services/analytics/report_scheduler_service.dart';
import 'package:cleartime/services/storage/secure_local_usage_store.dart';

import '../helpers/encrypted_store_helper.dart';

void main() {
  late ReportSchedulerService scheduler;
  late ApprovedReportRepository reportRepo;
  late SecureLocalUsageStore usageStore;

  setUp(() async {
    final deviceStore = await createTestDeviceStore();
    reportRepo = EncryptedApprovedReportRepository(store: deviceStore);
    usageStore = SecureLocalUsageStore(store: deviceStore);
    await reportRepo.clearLocalCache();
    await usageStore.wipeAllLocalData();
    scheduler = ReportSchedulerService(
      usageStore: usageStore,
      analyticsService: const LocalAnalyticsService(),
      reportBuilder: const ChildReportBuilder(),
      reportRepo: reportRepo,
    );
  });

  group('ReportSchedulerService Unit Tests', () {
    test('generateDeterministicReportKey builds unique idempotent key', () {
      final key = scheduler.generateDeterministicReportKey(
        familyId: 'fam-1',
        childId: 'child-1',
        period: ReportPeriod.weekly,
        periodStart: DateTime(2026, 8, 22),
        periodEnd: DateTime(2026, 8, 29),
      );

      expect(key, equals('fam-1_child-1_weekly_2026-8-22_2026-8-29'));
    });

    test('processReportSchedule generates approved report and saves locally', () async {
      final config = ReportConfiguration(
        id: 'cfg-1',
        familyId: 'fam-1',
        childId: 'child-1',
        title: 'Weekly Report',
        frequency: ReportFrequency.weekly,
        deliveryChannel: DeliveryChannel.inApp,
        isEnabled: true,
        allowedCategories: {'overallUsage', 'focusTime', 'goals'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Seed a local aggregate inside the report period (no demo data exists).
      await usageStore.saveDailyAggregate(
        DailyAggregate(
          dateString: '2026-08-29',
          totalMinutes: 120,
          focusMinutes: 45,
          breakCount: 3,
          unlockCount: 9,
          categoryMinutes: {'Education': 45, 'Games': 75},
          calculatedAt: DateTime(2026, 8, 29),
        ),
      );

      final result = await scheduler.processReportSchedule(
        config: config,
        childNickname: 'Alex',
        executionTime: DateTime(2026, 8, 29, 12, 0),
      );

      expect(result.generated, isTrue);
      expect(result.status, equals('SUCCESS'));
      expect(result.report, isNotNull);
      expect(result.report!.childNickname, equals('Alex'));

      // Verify report was saved in repository
      final saved = await reportRepo.getApprovedReports('child-1');
      expect(saved.length, equals(1));
    });

    test('processReportSchedule reports UNAVAILABLE_NO_LOCAL_DATA without aggregates', () async {
      final config = ReportConfiguration(
        id: 'cfg-2',
        familyId: 'fam-1',
        childId: 'child-1',
        title: 'Weekly Report',
        frequency: ReportFrequency.weekly,
        deliveryChannel: DeliveryChannel.inApp,
        isEnabled: true,
        allowedCategories: {'overallUsage'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await scheduler.processReportSchedule(
        config: config,
        childNickname: 'Alex',
        executionTime: DateTime(2026, 8, 29, 12, 0),
      );

      expect(result.generated, isFalse);
      expect(result.status, equals('UNAVAILABLE_NO_LOCAL_DATA'));
      expect(result.report, isNull);
    });

    test('processReportSchedule is strictly idempotent on duplicate runs', () async {
      final config = ReportConfiguration(
        id: 'cfg-1',
        familyId: 'fam-1',
        childId: 'child-1',
        title: 'Weekly Report',
        frequency: ReportFrequency.weekly,
        deliveryChannel: DeliveryChannel.inApp,
        isEnabled: true,
        allowedCategories: {'overallUsage', 'focusTime'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await usageStore.saveDailyAggregate(
        DailyAggregate(
          dateString: '2026-08-29',
          totalMinutes: 90,
          focusMinutes: 30,
          breakCount: 2,
          unlockCount: 6,
          categoryMinutes: {'Education': 30, 'Play': 60},
          calculatedAt: DateTime(2026, 8, 29),
        ),
      );

      final execTime = DateTime(2026, 8, 29, 12, 0);

      // First run generates
      final first = await scheduler.processReportSchedule(
        config: config,
        childNickname: 'Alex',
        executionTime: execTime,
      );
      expect(first.generated, isTrue);

      // Duplicate run within same period is skipped
      final second = await scheduler.processReportSchedule(
        config: config,
        childNickname: 'Alex',
        executionTime: execTime,
      );
      expect(second.generated, isFalse);
      expect(second.status, equals('SKIPPED_ALREADY_PROCESSED'));

      // Repository count should remain 1
      final saved = await reportRepo.getApprovedReports('child-1');
      expect(saved.length, equals(1));
    });

    test('generateForRequest returns unavailable when no aggregates exist', () async {
      final outcome = await scheduler.generateForRequest(
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'fam-1',
        period: ReportPeriod.daily,
      );

      expect(outcome.generated, isFalse);
      expect(outcome.status, equals('unavailable'));
      expect(outcome.report, isNull);
      expect(outcome.reason, contains('No local activity'));
    });

    test('generateForRequest builds Understand→Act snapshot from stored aggregates', () async {
      final today = DateTime.now();
      final dateStr = '${today.year.toString().padLeft(4, '0')}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      await usageStore.saveDailyAggregate(
        DailyAggregate(
          dateString: dateStr,
          totalMinutes: 150,
          focusMinutes: 60,
          breakCount: 4,
          unlockCount: 10,
          categoryMinutes: {'Education': 60, 'Creativity': 30, 'Games': 60},
          calculatedAt: today,
        ),
      );

      final outcome = await scheduler.generateForRequest(
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'fam-1',
        period: ReportPeriod.daily,
      );

      expect(outcome.generated, isTrue);
      expect(outcome.status, equals('ready'));
      expect(outcome.report, isNotNull);
      expect(outcome.report!.period, equals(ReportPeriod.daily));
      expect(outcome.report!.facts.totalScreenMinutes, equals(150));
      expect(outcome.report!.understandActSections, isNotEmpty);
      expect(outcome.report!.understandActSections.containsKey('at_a_glance'), isTrue);
      expect(outcome.report!.understandActSections.containsKey('next_steps'), isTrue);

      // The generated snapshot is persisted locally.
      final saved = await reportRepo.getApprovedReports('child-1');
      expect(saved.length, equals(1));
      expect(saved.first.id, equals(outcome.report!.id));
    });
  });
}
