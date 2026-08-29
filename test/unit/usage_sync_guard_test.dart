import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/privacy/usage_sync_guard.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/approved_trigger_event.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/reflection_model.dart';

void main() {
  group('UsageSyncGuard Core Architectural Barrier Tests', () {
    test('Strict rule RAW_CHILD_USAGE_MUST_NEVER_BE_SENT_TO_SERVER is true', () {
      expect(UsageSyncGuard.RAW_CHILD_USAGE_MUST_NEVER_BE_SENT_TO_SERVER, isTrue);
    });

    test('Throws StateError if raw UsageRecord attempts network sync serialization', () {
      final raw = UsageRecord(
        id: 'raw-1',
        packageName: 'com.google.android.youtube',
        appName: 'YouTube',
        category: 'Entertainment',
        startTime: DateTime.now().subtract(const Duration(hours: 1)),
        endTime: DateTime.now(),
        durationSeconds: 3600,
      );

      expect(() => UsageSyncGuard.assertRawUsageCannotBeSerializedForSync(raw),
          throwsStateError);
    });

    test('Throws StateError if raw UsageTimelineEntry attempts network sync serialization', () {
      final entry = UsageTimelineEntry(
        packageName: 'com.roblox.client',
        appName: 'Roblox',
        category: 'Games',
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        durationMinutes: 45,
      );

      expect(() => UsageSyncGuard.assertRawUsageCannotBeSerializedForSync(entry),
          throwsStateError);
    });

    test('Throws StateError if payload contains forbidden raw keys', () {
      final payload = {
        'id': 'payload-1',
        'packageName': 'com.instagram.android',
        'durationSeconds': 1800,
      };

      expect(() => UsageSyncGuard.assertRawUsageCannotBeSerializedForSync(payload),
          throwsStateError);
    });

    test('Throws StateError if private DailyReflection is passed for sync', () {
      final reflection = DailyReflection(
        id: 'ref-1',
        date: DateTime.now(),
        mood: ReflectionMood.productive,
        notes: 'Secret personal journal',
        createdAt: DateTime.now(),
      );

      expect(
          () => UsageSyncGuard.assertRawUsageCannotBeSerializedForSync(reflection),
          throwsStateError);
    });

    test('ApprovedReport, ApprovedTriggerEvent and TriggerConfiguration pass cleanly', () {
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
        ),
        summaryText: 'Factual privacy-safe summary',
        createdAt: DateTime.now(),
      );

      final triggerEvent = ApprovedTriggerEvent(
        id: 'evt-1',
        notificationId: 'notif-1',
        familyId: 'family-1',
        childId: 'child-1',
        triggerType: TriggerType.usageIncrease,
        threshold: 20.0,
        observedValue: 24.0,
        title: 'Weekly Usage Change',
        message: 'A configured wellbeing change was detected.',
        timestamp: DateTime.now(),
      );

      expect(() => UsageSyncGuard.assertRawUsageCannotReachRemoteRepository(report),
          returnsNormally);
      expect(
          () => UsageSyncGuard.assertRawUsageCannotReachRemoteRepository(triggerEvent),
          returnsNormally);
      expect(UsageSyncGuard.validateOutgoingSyncPayload(triggerEvent.toJson()),
          isTrue);
    });
  });
}
