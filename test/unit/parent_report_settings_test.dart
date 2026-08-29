import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/repositories/parent_report_settings_repository.dart';

void main() {
  group('ParentReportSettingsRepository Unit Tests', () {
    late ParentReportSettingsRepository repo;

    setUp(() {
      repo = InMemoryParentReportSettingsRepository();
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
  });
}
