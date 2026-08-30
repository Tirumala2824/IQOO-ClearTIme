import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/repositories/parent_report_settings_repository.dart';

import '../helpers/encrypted_store_helper.dart';

void main() {
  group('ParentReportSettingsRepository Unit Tests', () {
    late ParentReportSettingsRepository repo;

    setUp(() async {
      final store = await createTestDeviceStore();
      repo = EncryptedParentReportSettingsRepository(store: store);
    });

    test('Loads default report settings with all approved categories enabled', () async {
      final settings = await repo.getSettings('family-1');

      expect(settings.reportsEnabled, isTrue);
      expect(settings.frequency, equals(ReportPeriod.weekly));
      expect(settings.detail, equals(ReportDetailLevel.summary));
      expect(settings.notificationsEnabled, isTrue);
      expect(settings.categories.contains(ReportCategory.overallUsage), isTrue);
      expect(settings.categories.contains(ReportCategory.focusTime), isTrue);
      expect(settings.categories.contains(ReportCategory.breakSummary), isTrue);
      expect(settings.categories.contains(ReportCategory.goals), isTrue);
    });

    test('Parent updates configuration immediately without child approval workflow', () async {
      const updated = ParentReportSettings(
        reportsEnabled: true,
        frequency: ReportPeriod.daily,
        detail: ReportDetailLevel.detailed,
        notificationsEnabled: false,
        categories: {
          ReportCategory.overallUsage,
          ReportCategory.focusTime,
        },
      );

      await repo.updateSettings('family-1', updated);
      final fetched = await repo.getSettings('family-1');

      expect(fetched.frequency, equals(ReportPeriod.daily));
      expect(fetched.detail, equals(ReportDetailLevel.detailed));
      expect(fetched.notificationsEnabled, isFalse);
      expect(fetched.categories.length, equals(2));
      expect(fetched.categories.contains(ReportCategory.breakSummary), isFalse);
    });

    test('Settings are stored per family without cross-family leakage', () async {
      const familyA = ParentReportSettings(
        frequency: ReportPeriod.daily,
        categories: {ReportCategory.overallUsage},
      );
      const familyB = ParentReportSettings(
        frequency: ReportPeriod.monthly,
        categories: {ReportCategory.focusTime},
      );

      await repo.updateSettings('family-a', familyA);
      await repo.updateSettings('family-b', familyB);

      final fetchedA = await repo.getSettings('family-a');
      final fetchedB = await repo.getSettings('family-b');

      expect(fetchedA.frequency, equals(ReportPeriod.daily));
      expect(fetchedA.categories, equals({ReportCategory.overallUsage}));
      expect(fetchedB.frequency, equals(ReportPeriod.monthly));
      expect(fetchedB.categories, equals({ReportCategory.focusTime}));
    });
  });
}
