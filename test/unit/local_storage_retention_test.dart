import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/reflection_model.dart';
import 'package:cleartime/services/storage/secure_local_usage_store.dart';
import 'package:cleartime/services/storage/retention_config.dart';
import 'package:cleartime/data/repositories/local_reflection_repository.dart';

void main() {
  group('SecureLocalUsageStore and Retention Cleanup Tests', () {
    late SecureLocalUsageStore store;
    final now = DateTime.now();

    setUp(() async {
      store = SecureLocalUsageStore(
        retentionConfig: const RetentionConfig(
          rawUsageRetentionDays: 30,
          aggregateRetentionDays: 90,
        ),
      );
      await store.initialize();
    });

    test('Saves encrypted usage records and retrieves them cleanly without data loss', () async {
      final record = UsageRecord(
        id: 'rec-test-1',
        packageName: 'com.test.app',
        appName: 'Test App',
        category: 'Learning',
        startTime: now.subtract(const Duration(minutes: 30)),
        endTime: now,
        durationSeconds: 1800,
      );

      await store.saveUsage(record);
      final retrieved = await store.getUsage();
      expect(retrieved.length, equals(1));
      expect(retrieved.first.id, equals('rec-test-1'));
      expect(retrieved.first.durationMinutes, equals(30));
    });

    test('DailyAggregate save and retrieval works with date strings', () async {
      final aggregate = DailyAggregate(
        dateString: '2026-08-29',
        totalMinutes: 120,
        focusMinutes: 80,
        breakCount: 4,
        unlockCount: 16,
        categoryMinutes: {'Learning': 80, 'Play': 40},
        calculatedAt: now,
      );

      await store.saveDailyAggregate(aggregate);
      final fetched = await store.getDailyAggregate(DateTime(2026, 8, 29));
      expect(fetched, isNotNull);
      expect(fetched?.totalMinutes, equals(120));
      expect(fetched?.categoryMinutes['Learning'], equals(80));
    });

    test('deleteExpiredUsage automatically purges records older than 30 days retention policy', () async {
      // Recent record (yesterday)
      final recentRecord = UsageRecord(
        id: 'rec-recent',
        packageName: 'com.recent.app',
        appName: 'Recent',
        category: 'Learning',
        startTime: now.subtract(const Duration(days: 2)),
        endTime: now.subtract(const Duration(days: 2, minutes: -30)),
        durationSeconds: 1800,
      );

      // Expired record (45 days ago)
      final oldRecord = UsageRecord(
        id: 'rec-expired',
        packageName: 'com.old.app',
        appName: 'Old Expired',
        category: 'Games',
        startTime: now.subtract(const Duration(days: 45)),
        endTime: now.subtract(const Duration(days: 45, minutes: -30)),
        durationSeconds: 1800,
      );

      await store.saveUsage(recentRecord);
      await store.saveUsage(oldRecord);

      final initialList = await store.getUsage();
      expect(initialList.length, equals(2));

      // Run automated retention purging
      final purgedCount = await store.deleteExpiredUsage();
      expect(purgedCount, equals(1));

      final remaining = await store.getUsage();
      expect(remaining.length, equals(1));
      expect(remaining.first.id, equals('rec-recent'));
    });

    test('wipeAllLocalData purges all local storage upon request', () async {
      await store.saveUsage(
        UsageRecord(
          id: 'rec-wipe',
          packageName: 'com.app',
          appName: 'App',
          category: 'General',
          startTime: now,
          endTime: now,
          durationSeconds: 60,
        ),
      );

      await store.wipeAllLocalData();
      final list = await store.getUsage();
      expect(list.isEmpty, isTrue);
    });

    test('LocalReflectionRepository saves, fetches, and deletes reflections locally', () async {
      final reflectionRepo = InMemoryLocalReflectionRepository();
      final initial = await reflectionRepo.getReflections();
      expect(initial.isNotEmpty, isTrue);

      final newReflection = DailyReflection(
        id: 'ref-custom',
        date: DateTime(now.year, now.month, now.day),
        mood: ReflectionMood.relaxing,
        notes: 'Had a peaceful screen-free afternoon',
        createdAt: now,
      );

      await reflectionRepo.saveReflection(newReflection);
      final today = await reflectionRepo.getTodayReflection();
      expect(today?.mood, equals(ReflectionMood.relaxing));
      expect(today?.notes, contains('peaceful'));

      await reflectionRepo.deleteReflection('ref-custom');
      expect((await reflectionRepo.getReflections()).any((r) => r.id == 'ref-custom'), isFalse);
    });
  });
}
