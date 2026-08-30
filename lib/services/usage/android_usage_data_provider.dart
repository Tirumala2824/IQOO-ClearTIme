import 'package:flutter/foundation.dart';

import '../../core/platform/usage/android_usage_channel.dart';
import '../../core/services/abstractions/local_usage_store.dart';
import '../../core/services/abstractions/usage_data_provider.dart';
import '../../data/models/usage_models.dart';

/// Production usage data provider backed by Android UsageStatsManager.
///
/// Access states are explicit: [UsageAccessState.unsupported] on platforms
/// without an authorized activity API, [UsageAccessState.permissionNeeded]
/// before the child grants Usage Access, [UsageAccessState.ready] once real
/// data can be read, and [UsageAccessState.collectionFailed] when a read
/// fails. No usage metric is ever synthesized.
///
/// CRITICAL PRIVACY: All data stays strictly on-device.
class AndroidUsageDataProvider implements UsageDataProvider {
  final AndroidUsageChannel _channel;
  final LocalUsageStore? _usageStore;

  AndroidUsageDataProvider({AndroidUsageChannel? channel, LocalUsageStore? usageStore})
      : _channel = channel ?? AndroidUsageChannel(),
        _usageStore = usageStore;

  bool get _isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<UsageAccessState> getUsageAccessState() async {
    if (!_isAndroid) return UsageAccessState.unsupported;
    if (!await hasUsagePermission()) {
      return UsageAccessState.permissionNeeded;
    }
    return UsageAccessState.ready;
  }

  @override
  Future<bool> hasUsagePermission() async {
    if (!_isAndroid) return false;
    return await _channel.hasUsagePermission();
  }

  @override
  Future<bool> requestUsagePermission() async {
    if (!_isAndroid) return false;
    return await _channel.requestUsagePermission();
  }

  Future<void> _ensureReady() async {
    final state = await getUsageAccessState();
    switch (state) {
      case UsageAccessState.ready:
        return;
      case UsageAccessState.permissionNeeded:
        throw const UsageAccessRequiredException();
      case UsageAccessState.unsupported:
        throw const UsageUnsupportedException();
      case UsageAccessState.collectionFailed:
        throw const UsageCollectionFailedException();
    }
  }

  @override
  Future<UsageSummary> getTodayUsage() async {
    await _ensureReady();

    final rawData = await _channel.getTodayUsageData();
    final totalMinutes = (rawData['totalMinutes'] as num? ?? 0).toInt();

    final catMap = Map<String, int>.from(rawData['categoryMinutes'] as Map? ?? {});
    final topAppsRaw = (rawData['topApps'] as List<dynamic>? ?? []);

    final categories = <CategoryUsage>[];
    if (totalMinutes > 0) {
      catMap.forEach((category, minutes) {
        categories.add(CategoryUsage(
          category: category,
          totalMinutes: minutes,
          percentage: ((minutes / totalMinutes) * 100).clamp(0.0, 100.0),
        ));
      });
    }

    final topApps = topAppsRaw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return AppUsageSummary(
        packageName: map['packageName'] as String? ?? '',
        appName: map['appName'] as String? ?? '',
        category: map['category'] as String? ?? 'General',
        durationMinutes: (map['durationMinutes'] as num? ?? 0).toInt(),
      );
    }).toList();

    final focusMinutes = (catMap['Education'] ?? 0) + (catMap['Creativity'] ?? 0);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

    int calculatedBreaks = 0;
    var unlockCount = (rawData['unlockCount'] as num? ?? 0).toInt();
    try {
      final timeline = await _channel.getTimeline(
        startOfDay.millisecondsSinceEpoch,
        now.millisecondsSinceEpoch,
      );
      if (timeline.length > 1) {
        for (int i = 0; i < timeline.length - 1; i++) {
          final gapMinutes = timeline[i + 1]
              .startTime
              .difference(timeline[i].endTime)
              .inMinutes;
          if (gapMinutes >= 5) {
            calculatedBreaks++;
          }
        }
      }
      if (unlockCount == 0 && timeline.isNotEmpty) {
        unlockCount = timeline.length;
      }
    } on UsageChannelException {
      // Timeline is a best-effort enrichment; aggregate data remains real.
    }

    double changePct = 0.0;
    final yestStart = startOfDay.subtract(const Duration(days: 1));
    final yestEnd = DateTime(yestStart.year, yestStart.month, yestStart.day, 23, 59, 59);
    final yestData = await _channel.getUsageRange(
      yestStart.millisecondsSinceEpoch,
      yestEnd.millisecondsSinceEpoch,
    );
    final yestTotal = (yestData['totalMinutes'] as num? ?? 0).toInt();
    if (yestTotal > 0 && totalMinutes > 0) {
      changePct = ((totalMinutes - yestTotal) / yestTotal) * 100.0;
    }

    final summary = UsageSummary(
      totalMinutes: totalMinutes,
      focusMinutes: focusMinutes,
      breakCount: calculatedBreaks,
      screenUnlockCount: unlockCount,
      changePercentageFromYesterday: changePct,
      categories: categories,
      topApps: topApps,
    );

    // Persist today's aggregate locally for reports and analytics
    final store = _usageStore;
    if (store != null) {
      final dateStr = '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      await store.saveDailyAggregate(DailyAggregate(
        dateString: dateStr,
        totalMinutes: totalMinutes,
        focusMinutes: focusMinutes,
        breakCount: calculatedBreaks,
        unlockCount: unlockCount,
        categoryMinutes: catMap,
        calculatedAt: DateTime.now(),
      ));
    }

    return summary;
  }

  /// Builds real per-day aggregates for the requested recent days and
  /// persists each one in the encrypted local store for reporting/review.
  Future<List<DailyUsage>> _getHistoricalUsage(int days) async {
    await _ensureReady();

    final buckets = await _channel.getDailyBuckets(days);
    final list = <DailyUsage>[];

    for (final bucket in buckets) {
      final dayStartMs = (bucket['dayStart'] as num? ?? 0).toInt();
      final catMap =
          Map<String, int>.from(bucket['categoryMinutes'] as Map? ?? {});
      final totalMinutes = (bucket['totalMinutes'] as num? ?? 0).toInt();
      final dayDate = DateTime.fromMillisecondsSinceEpoch(dayStartMs);

      list.add(DailyUsage(
        date: DateTime(dayDate.year, dayDate.month, dayDate.day),
        totalMinutes: totalMinutes,
        focusMinutes: (catMap['Education'] ?? 0) + (catMap['Creativity'] ?? 0),
        unlockCount: (bucket['unlockCount'] as num? ?? 0).toInt(),
        categoryMinutes: catMap,
      ));

      // Persist the aggregate locally for reporting and retention cleanup.
      final store = _usageStore;
      if (store != null) {
        final dateStr = '${dayDate.year.toString().padLeft(4, '0')}-'
            '${dayDate.month.toString().padLeft(2, '0')}-'
            '${dayDate.day.toString().padLeft(2, '0')}';
        await store.saveDailyAggregate(DailyAggregate(
          dateString: dateStr,
          totalMinutes: totalMinutes,
          focusMinutes: (catMap['Education'] ?? 0) + (catMap['Creativity'] ?? 0),
          breakCount: 0,
          unlockCount: (bucket['unlockCount'] as num? ?? 0).toInt(),
          categoryMinutes: catMap,
          calculatedAt: DateTime.now(),
        ));
      }
    }

    return list;
  }

  @override
  Future<List<DailyUsage>> getDailyUsage() => _getHistoricalUsage(7);

  @override
  Future<List<DailyUsage>> getWeeklyUsage() => _getHistoricalUsage(7);

  @override
  Future<List<DailyUsage>> getMonthlyUsage() => _getHistoricalUsage(30);

  @override
  Future<List<CategoryUsage>> getCategoryUsage() async {
    final today = await getTodayUsage();
    return today.categories;
  }

  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async {
    await _ensureReady();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

    return await _channel.getTimeline(
      startOfDay.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<FocusSession>> getFocusSessions() async {
    await _ensureReady();
    final timeline = await getUsageTimeline();

    final focusEntries = timeline.where((t) {
      final lower = t.category.toLowerCase();
      return lower.contains('edu') ||
          lower.contains('learn') ||
          lower.contains('creat') ||
          lower.contains('read') ||
          lower.contains('book');
    }).toList();

    return focusEntries.map((e) {
      return FocusSession(
        id: 'fs-${e.startTime.millisecondsSinceEpoch}',
        startTime: e.startTime,
        endTime: e.endTime,
        targetMinutes: e.durationMinutes,
        actualMinutes: e.durationMinutes,
        isCompleted: true,
        title: e.appName,
        category: e.category,
      );
    }).toList();
  }
}