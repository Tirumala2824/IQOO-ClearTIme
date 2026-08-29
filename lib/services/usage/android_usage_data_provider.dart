import '../../core/platform/usage/android_usage_channel.dart';
import '../../core/services/abstractions/usage_data_provider.dart';
import '../../data/models/usage_models.dart';

/// Production Android Usage Data Provider.
///
/// Communicates directly with native Android UsageStatsManager via platform channels.
/// CRITICAL PRIVACY: All data stays strictly on-device.
class AndroidUsageDataProvider implements UsageDataProvider {
  final AndroidUsageChannel _channel;

  AndroidUsageDataProvider({AndroidUsageChannel? channel})
      : _channel = channel ?? AndroidUsageChannel();

  @override
  Future<bool> hasUsagePermission() async {
    return await _channel.hasUsagePermission();
  }

  @override
  Future<bool> requestUsagePermission() async {
    return await _channel.requestUsagePermission();
  }

  @override
  Future<UsageSummary> getTodayUsage() async {
    final hasPermission = await _channel.hasUsagePermission();
    if (!hasPermission) {
      return const UsageSummary(
        totalMinutes: 0,
        focusMinutes: 0,
        breakCount: 0,
        screenUnlockCount: 0,
        categories: [],
        topApps: [],
      );
    }

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

    // Calculate approximate focus minutes from Education & Creativity apps
    final focusMinutes = (catMap['Education'] ?? 0) + (catMap['Creativity'] ?? 0);

    // Calculate real breaks and unlocks from today's timeline
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final timeline = await _channel.getTimeline(
      startOfDay.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );

    int calculatedBreaks = 0;
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

    final unlockCount = timeline.isNotEmpty ? timeline.length : 0;

    // Calculate percentage change compared to yesterday
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

    return UsageSummary(
      totalMinutes: totalMinutes,
      focusMinutes: focusMinutes,
      breakCount: calculatedBreaks,
      screenUnlockCount: unlockCount,
      changePercentageFromYesterday: changePct,
      categories: categories,
      topApps: topApps,
    );
  }

  @override
  Future<List<DailyUsage>> getDailyUsage() async {
    final now = DateTime.now();
    final list = <DailyUsage>[];

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final start = DateTime(day.year, day.month, day.day, 0, 0, 0);
      final end = DateTime(day.year, day.month, day.day, 23, 59, 59);

      final data = await _channel.getUsageRange(
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      );

      final totalMinutes = (data['totalMinutes'] as num? ?? 0).toInt();
      final catMap = Map<String, int>.from(data['categoryMinutes'] as Map? ?? {});

      list.add(DailyUsage(
        date: start,
        totalMinutes: totalMinutes,
        focusMinutes: (catMap['Education'] ?? 0) + (catMap['Creativity'] ?? 0),
        unlockCount: 0,
        categoryMinutes: catMap,
      ));
    }

    return list;
  }

  @override
  Future<List<DailyUsage>> getWeeklyUsage() => getDailyUsage();

  @override
  Future<List<DailyUsage>> getMonthlyUsage() async {
    return getDailyUsage();
  }

  @override
  Future<List<CategoryUsage>> getCategoryUsage() async {
    final today = await getTodayUsage();
    return today.categories;
  }

  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);

    return await _channel.getTimeline(
      startOfDay.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );
  }

  @override
  Future<List<FocusSession>> getFocusSessions() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final timeline = await _channel.getTimeline(
      startOfDay.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
    );

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
