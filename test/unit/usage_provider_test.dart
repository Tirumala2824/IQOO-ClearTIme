import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/platform/usage/android_usage_channel.dart';
import 'package:cleartime/core/services/abstractions/local_usage_store.dart';
import 'package:cleartime/core/services/abstractions/usage_data_provider.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/services/usage/android_usage_data_provider.dart';

/// In-memory [AndroidUsageChannel] for tests. Mirrors the real channel's
/// contract: collection methods throw [UsageChannelException] on failure.
class FakeAndroidUsageChannel extends AndroidUsageChannel {
  bool permissionGranted;
  bool throwOnCollection;
  final Map<String, dynamic> todayData;
  final Map<String, dynamic> rangeData;
  final List<Map<String, dynamic>> dailyBuckets;
  final List<UsageTimelineEntry> timeline;

  FakeAndroidUsageChannel({
    this.permissionGranted = true,
    this.throwOnCollection = false,
    this.todayData = const {},
    this.rangeData = const {},
    this.dailyBuckets = const [],
    this.timeline = const [],
  });

  @override
  Future<bool> hasUsagePermission() async => permissionGranted;

  @override
  Future<bool> requestUsagePermission() async {
    permissionGranted = true;
    return true;
  }

  @override
  Future<Map<String, dynamic>> getTodayUsageData() async {
    if (throwOnCollection) {
      throw const UsageChannelException('Usage collection failed.');
    }
    return todayData;
  }

  @override
  Future<Map<String, dynamic>> getUsageRange(
      int startTimeMs, int endTimeMs) async {
    if (throwOnCollection) {
      throw const UsageChannelException('Usage collection failed.');
    }
    return rangeData;
  }

  @override
  Future<List<Map<String, dynamic>>> getDailyBuckets(int days) async {
    return dailyBuckets;
  }

  @override
  Future<List<UsageTimelineEntry>> getTimeline(
      int startTimeMs, int endTimeMs) async {
    return timeline;
  }
}

/// Records daily aggregates persisted by the provider.
class RecordingLocalUsageStore implements LocalUsageStore {
  final List<DailyAggregate> savedAggregates = [];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> saveUsage(UsageRecord usage) async {}

  @override
  Future<void> saveUsageBatch(List<UsageRecord> records) async {}

  @override
  Future<List<UsageRecord>> getUsage({DateTime? start, DateTime? end}) async => [];

  @override
  Future<void> saveDailyAggregate(DailyAggregate aggregate) async {
    savedAggregates.add(aggregate);
  }

  @override
  Future<DailyAggregate?> getDailyAggregate(DateTime date) async => null;

  @override
  Future<List<DailyAggregate>> getWeeklyAggregate() async => [];

  @override
  Future<List<DailyAggregate>> getDailyAggregatesInRange(
      String start, String end) async => [];

  @override
  Future<void> deleteUsage(String id) async {}

  @override
  Future<int> deleteExpiredUsage() async => 0;

  @override
  Future<void> wipeAllLocalData() async {}
}

void main() {
  group('AndroidUsageDataProvider Unit Tests', () {
    setUp(() {
      // The Dart VM defaults to android under `flutter test`, but make it
      // explicit so platform gating is deterministic.
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    List<Map<String, dynamic>> buildBuckets(int days) {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      return List.generate(days, (i) {
        final day = start.subtract(Duration(days: days - 1 - i));
        return {
          'dayStart': DateTime(day.year, day.month, day.day)
              .millisecondsSinceEpoch,
          'totalMinutes': 100,
          'unlockCount': 5,
          'categoryMinutes': {'Education': 40, 'Creativity': 20},
        };
      });
    }

    test('getUsageAccessState is ready when permission granted on Android', () async {
      final provider = AndroidUsageDataProvider(
        channel: FakeAndroidUsageChannel(permissionGranted: true),
      );

      expect(await provider.hasUsagePermission(), isTrue);
      expect(await provider.getUsageAccessState(), equals(UsageAccessState.ready));
    });

    test('getUsageAccessState is permissionNeeded before grant', () async {
      final channel = FakeAndroidUsageChannel(permissionGranted: false);
      final provider = AndroidUsageDataProvider(channel: channel);

      expect(await provider.hasUsagePermission(), isFalse);
      expect(
          await provider.getUsageAccessState(), equals(UsageAccessState.permissionNeeded));

      // Requesting permission opens settings and flips the fake grant.
      expect(await provider.requestUsagePermission(), isTrue);
      expect(await provider.hasUsagePermission(), isTrue);
      expect(await provider.getUsageAccessState(), equals(UsageAccessState.ready));
    });

    test('getUsageAccessState is unsupported off Android', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final provider = AndroidUsageDataProvider(
        channel: FakeAndroidUsageChannel(permissionGranted: true),
      );

      expect(await provider.getUsageAccessState(), equals(UsageAccessState.unsupported));
      expect(await provider.hasUsagePermission(), isFalse);
      expect(() => provider.getTodayUsage(), throwsA(isA<UsageUnsupportedException>()));
    });

    test('getTodayUsage builds a real summary from channel data', () async {
      final startOfDay = DateTime.now();
      final dayStart = DateTime(startOfDay.year, startOfDay.month, startOfDay.day, 9);
      final channel = FakeAndroidUsageChannel(
        permissionGranted: true,
        todayData: {
          'totalMinutes': 120,
          'unlockCount': 15,
          'categoryMinutes': {'Education': 60, 'Creativity': 20, 'Games': 40},
          'topApps': [
            {
              'packageName': 'com.example.education',
              'appName': 'Math Learning',
              'category': 'Education',
              'durationMinutes': 60,
            },
          ],
        },
        rangeData: {'totalMinutes': 100},
        timeline: [
          UsageTimelineEntry(
            packageName: 'com.example.education',
            appName: 'Math Learning',
            category: 'Education',
            startTime: dayStart,
            endTime: dayStart.add(const Duration(minutes: 30)),
            durationMinutes: 30,
          ),
          UsageTimelineEntry(
            packageName: 'com.example.games',
            appName: 'Puzzle',
            category: 'Games',
            startTime: dayStart.add(const Duration(minutes: 36)),
            endTime: dayStart.add(const Duration(minutes: 66)),
            durationMinutes: 30,
          ),
        ],
      );
      final provider = AndroidUsageDataProvider(channel: channel);

      final summary = await provider.getTodayUsage();

      expect(summary.totalMinutes, equals(120));
      expect(summary.focusMinutes, equals(80)); // Education + Creativity
      expect(summary.screenUnlockCount, equals(15));
      expect(summary.breakCount, equals(1)); // one >=5min gap between sessions
      expect(summary.changePercentageFromYesterday, equals(20.0));
      expect(summary.categories.length, equals(3));
      expect(summary.categories.first.category, equals('Education'));
      expect(summary.categories.first.percentage, equals(50.0));
      expect(summary.topApps.length, equals(1));
      expect(summary.topApps.first.appName, equals('Math Learning'));
    });

    test('getTodayUsage throws UsageAccessRequiredException without permission', () async {
      final provider = AndroidUsageDataProvider(
        channel: FakeAndroidUsageChannel(permissionGranted: false),
      );

      expect(
          () => provider.getTodayUsage(), throwsA(isA<UsageAccessRequiredException>()));
    });

    test('channel collection failure surfaces as UsageChannelException', () async {
      final provider = AndroidUsageDataProvider(
        channel: FakeAndroidUsageChannel(
          permissionGranted: true,
          throwOnCollection: true,
        ),
      );

      expect(() => provider.getTodayUsage(), throwsA(isA<UsageChannelException>()));
    });

    test('getWeeklyUsage returns exactly 7 real daily buckets and persists aggregates', () async {
      final channel = FakeAndroidUsageChannel(
        permissionGranted: true,
        dailyBuckets: buildBuckets(7),
      );
      final store = RecordingLocalUsageStore();
      final provider = AndroidUsageDataProvider(channel: channel, usageStore: store);

      final weekly = await provider.getWeeklyUsage();

      expect(weekly.length, equals(7));
      expect(weekly.first.totalMinutes, equals(100));
      expect(weekly.first.focusMinutes, equals(60)); // Education + Creativity
      expect(weekly.first.unlockCount, equals(5));
      expect(weekly.first.categoryMinutes['Education'], equals(40));

      // Each daily bucket is persisted into the local usage store.
      expect(store.savedAggregates.length, equals(7));
      expect(store.savedAggregates.first.totalMinutes, equals(100));
      expect(store.savedAggregates.first.dateString,
          equals(_dateString(weekly.first.date)));
    });

    test('getMonthlyUsage returns exactly 30 real daily buckets', () async {
      final channel = FakeAndroidUsageChannel(
        permissionGranted: true,
        dailyBuckets: buildBuckets(30),
      );
      final provider = AndroidUsageDataProvider(
        channel: channel,
        usageStore: RecordingLocalUsageStore(),
      );

      final monthly = await provider.getMonthlyUsage();

      expect(monthly.length, equals(30));
      expect(monthly.first.totalMinutes, equals(100));
      expect(monthly.last.totalMinutes, equals(100));
    });

    test('getDailyUsage mirrors the 7-day buckets', () async {
      final provider = AndroidUsageDataProvider(
        channel: FakeAndroidUsageChannel(
          permissionGranted: true,
          dailyBuckets: buildBuckets(7),
        ),
      );

      final daily = await provider.getDailyUsage();
      expect(daily.length, equals(7));
    });
  });
}

String _dateString(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
