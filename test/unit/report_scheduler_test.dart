import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';
import 'package:cleartime/services/analytics/child_report_builder.dart';
import 'package:cleartime/services/analytics/local_analytics_service.dart';
import 'package:cleartime/services/analytics/report_scheduler_service.dart';
import 'package:cleartime/services/storage/secure_local_usage_store.dart';

void main() {
  late ReportSchedulerService scheduler;
  late InMemoryApprovedReportRepository reportRepo;
  late SecureLocalUsageStore usageStore;

  setUp(() {
    reportRepo = InMemoryApprovedReportRepository(seedSampleData: false);
    usageStore = SecureLocalUsageStore();
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
  });
}
