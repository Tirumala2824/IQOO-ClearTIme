import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/privacy/privacy_guard.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/reflection_model.dart';

void main() {
  group('Privacy Barrier & Cloud Sync Audit Unit Tests', () {
    test('Throws StateError if raw UsageRecord is passed to cloud sync assertion', () {
      final record = UsageRecord(
        id: 'raw-1',
        packageName: 'com.example.app',
        appName: 'Example App',
        category: 'Games',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        durationSeconds: 1200,
      );

      expect(() => PrivacyGuard.assertCloudSafe(record), throwsStateError);
    });

    test('Throws StateError if UsageTimelineEntry is passed to cloud sync assertion', () {
      final entry = UsageTimelineEntry(
        packageName: 'com.example.app',
        appName: 'Example App',
        category: 'Learning',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        durationMinutes: 20,
      );

      expect(() => PrivacyGuard.assertCloudSafe(entry), throwsStateError);
    });

    test('Throws StateError if private DailyReflection is passed to cloud sync assertion', () {
      final reflection = DailyReflection(
        id: 'ref-1',
        date: DateTime.parse('2026-08-29'),
        mood: ReflectionMood.productive,
        notes: 'Private mindful journaling notes',
        createdAt: DateTime.now(),
      );

      expect(() => PrivacyGuard.assertCloudSafe(reflection), throwsStateError);
    });

    test('ApprovedReport passes cloud sync assertion without privacy violation', () {
      final report = ApprovedReport(
        id: 'rep-safe',
        childId: 'child-1',
        childNickname: 'Alex',
        familyId: 'family-1',
        period: ReportPeriod.weekly,
        periodStart: DateTime.now().subtract(const Duration(days: 7)),
        periodEnd: DateTime.now(),
        facts: const ReportFacts(
          totalScreenMinutes: 800,
          focusMinutes: 300,
          breakCount: 15,
          goalsCompletedCount: 4,
          goalsTotalCount: 5,
        ),
        summaryText: 'Factual summary',
        createdAt: DateTime.now(),
      );

      expect(() => PrivacyGuard.assertCloudSafe(report.toJson()), returnsNormally);
    });
  });
}
