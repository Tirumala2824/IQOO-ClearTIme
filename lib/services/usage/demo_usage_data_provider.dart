import '../../core/services/abstractions/usage_data_provider.dart';
import '../../data/models/usage_models.dart';

/// Development Demo Adapter for previewing and local testing.
///
/// Contains realistic, deterministic offline usage metrics.
/// PRIVACY: Strictly local and in-memory.
class DemoUsageDataProvider implements UsageDataProvider {
  bool _mockPermissionGranted = true;
  bool isDynamic;

  DemoUsageDataProvider({this.isDynamic = true});

  void setMockPermission(bool granted) {
    _mockPermissionGranted = granted;
  }

  @override
  Future<bool> hasUsagePermission() async {
    return _mockPermissionGranted;
  }

  @override
  Future<bool> requestUsagePermission() async {
    _mockPermissionGranted = true;
    return true;
  }

  @override
  Future<UsageSummary> getTodayUsage() async {
    if (!_mockPermissionGranted) {
      return const UsageSummary(
        totalMinutes: 0,
        focusMinutes: 0,
        breakCount: 0,
        screenUnlockCount: 0,
        categories: [],
        topApps: [],
      );
    }

    if (!isDynamic) {
      return const UsageSummary(
        totalMinutes: 170,
        focusMinutes: 105,
        breakCount: 5,
        screenUnlockCount: 14,
        changePercentageFromYesterday: -14.2,
        categories: [
          CategoryUsage(category: 'Education & Learning', totalMinutes: 85, percentage: 50.0, appCount: 2),
          CategoryUsage(category: 'Creativity & Art', totalMinutes: 40, percentage: 23.5, appCount: 1),
          CategoryUsage(category: 'Games & Play', totalMinutes: 30, percentage: 17.6, appCount: 2),
          CategoryUsage(category: 'Utilities', totalMinutes: 15, percentage: 8.8, appCount: 3),
        ],
        topApps: [
          AppUsageSummary(packageName: 'org.khanacademy.android', appName: 'Khan Academy Kids', category: 'Education & Learning', durationMinutes: 55, launchCount: 3),
          AppUsageSummary(packageName: 'com.duolingo', appName: 'Duolingo', category: 'Education & Learning', durationMinutes: 30, launchCount: 2),
          AppUsageSummary(packageName: 'com.toca.hair', appName: 'Toca Life World', category: 'Creativity & Art', durationMinutes: 40, launchCount: 2),
          AppUsageSummary(packageName: 'com.roblox.client', appName: 'Roblox', category: 'Games & Play', durationMinutes: 30, launchCount: 1),
        ],
      );
    }

    // Dynamic data: scales with time of day so it looks real
    final now = DateTime.now();
    final hourFactor = now.hour / 24.0; // 0.0 at midnight, 1.0 at 11pm
    final minuteJitter = (now.minute % 7) * 3; // 0-18 minute jitter

    final totalMin = (50 + (hourFactor * 180) + minuteJitter).round().clamp(30, 280);
    final focusMin = (totalMin * 0.55 + minuteJitter * 0.5).round().clamp(10, totalMin);
    final breaks = (hourFactor * 6 + (now.minute % 3)).round().clamp(0, 8);
    final unlocks = (hourFactor * 20 + (now.minute % 5)).round().clamp(2, 30);
    final changePercent = -14.2 + (now.minute % 10) * 1.5;

    final eduMin = (focusMin * 0.6).round();
    final creativityMin = (totalMin * 0.2).round();
    final gamesMin = (totalMin * 0.25).round();
    final utilMin = totalMin - eduMin - creativityMin - gamesMin;

    final categories = [
      CategoryUsage(category: 'Education & Learning', totalMinutes: eduMin, percentage: (eduMin / totalMin * 100), appCount: 2),
      CategoryUsage(category: 'Creativity & Art', totalMinutes: creativityMin, percentage: (creativityMin / totalMin * 100), appCount: 1),
      CategoryUsage(category: 'Games & Play', totalMinutes: gamesMin, percentage: (gamesMin / totalMin * 100), appCount: 2),
      CategoryUsage(category: 'Utilities', totalMinutes: utilMin, percentage: (utilMin / totalMin * 100), appCount: 3),
    ];

    final topApps = [
      AppUsageSummary(packageName: 'com.duolingo', appName: 'Duolingo', category: 'Education & Learning', durationMinutes: (eduMin * 0.55).round(), launchCount: 3),
      AppUsageSummary(packageName: 'com.khanacademy', appName: 'Khan Academy Kids', category: 'Education & Learning', durationMinutes: (eduMin * 0.45).round(), launchCount: 2),
      AppUsageSummary(packageName: 'com.procreate.pocket', appName: 'Sketch & Draw', category: 'Creativity & Art', durationMinutes: creativityMin, launchCount: 1),
      AppUsageSummary(packageName: 'com.mojang.minecraftpe', appName: 'Minecraft Creative', category: 'Games & Play', durationMinutes: (gamesMin * 0.65).round(), launchCount: 1),
      AppUsageSummary(packageName: 'com.chess.kid', appName: 'Chess Adventure', category: 'Games & Play', durationMinutes: (gamesMin * 0.35).round(), launchCount: 1),
    ];

    return UsageSummary(
      totalMinutes: totalMin,
      focusMinutes: focusMin,
      breakCount: breaks,
      screenUnlockCount: unlocks,
      changePercentageFromYesterday: changePercent,
      categories: categories,
      topApps: topApps,
    );
  }

  @override
  Future<List<DailyUsage>> getDailyUsage() async {
    final now = DateTime.now();
    return [
      DailyUsage(
        date: now.subtract(const Duration(days: 6)),
        totalMinutes: 195,
        focusMinutes: 80,
        unlockCount: 22,
        categoryMinutes: {'Education': 80, 'Games': 60, 'Creativity': 35, 'Utilities': 20},
      ),
      DailyUsage(
        date: now.subtract(const Duration(days: 5)),
        totalMinutes: 180,
        focusMinutes: 90,
        unlockCount: 19,
        categoryMinutes: {'Education': 90, 'Games': 50, 'Creativity': 25, 'Utilities': 15},
      ),
      DailyUsage(
        date: now.subtract(const Duration(days: 4)),
        totalMinutes: 210,
        focusMinutes: 75,
        unlockCount: 25,
        categoryMinutes: {'Education': 75, 'Games': 85, 'Creativity': 30, 'Utilities': 20},
      ),
      DailyUsage(
        date: now.subtract(const Duration(days: 3)),
        totalMinutes: 160,
        focusMinutes: 95,
        unlockCount: 17,
        categoryMinutes: {'Education': 95, 'Games': 35, 'Creativity': 20, 'Utilities': 10},
      ),
      DailyUsage(
        date: now.subtract(const Duration(days: 2)),
        totalMinutes: 175,
        focusMinutes: 85,
        unlockCount: 20,
        categoryMinutes: {'Education': 85, 'Games': 45, 'Creativity': 30, 'Utilities': 15},
      ),
      DailyUsage(
        date: now.subtract(const Duration(days: 1)),
        totalMinutes: 198,
        focusMinutes: 90,
        unlockCount: 21,
        categoryMinutes: {'Education': 90, 'Games': 60, 'Creativity': 30, 'Utilities': 18},
      ),
      DailyUsage(
        date: now,
        totalMinutes: 170,
        focusMinutes: 105,
        unlockCount: 18,
        categoryMinutes: {'Education': 65, 'Creativity': 40, 'Games': 45, 'Utilities': 20},
      ),
    ];
  }

  @override
  Future<List<DailyUsage>> getWeeklyUsage() => getDailyUsage();

  @override
  Future<List<DailyUsage>> getMonthlyUsage() => getDailyUsage();

  @override
  Future<List<CategoryUsage>> getCategoryUsage() async {
    final today = await getTodayUsage();
    return today.categories;
  }

  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async {
    final now = DateTime.now();
    return [
      UsageTimelineEntry(
        packageName: 'com.khanacademy',
        appName: 'Khan Academy Kids',
        category: 'Education',
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.subtract(const Duration(hours: 3, minutes: 30)),
        durationMinutes: 30,
      ),
      UsageTimelineEntry(
        packageName: 'com.duolingo',
        appName: 'Duolingo',
        category: 'Education',
        startTime: now.subtract(const Duration(hours: 2, minutes: 30)),
        endTime: now.subtract(const Duration(hours: 1, minutes: 55)),
        durationMinutes: 35,
      ),
      UsageTimelineEntry(
        packageName: 'com.procreate.pocket',
        appName: 'Sketch & Draw',
        category: 'Creativity',
        startTime: now.subtract(const Duration(hours: 1, minutes: 15)),
        endTime: now.subtract(const Duration(minutes: 35)),
        durationMinutes: 40,
      ),
    ];
  }

  @override
  Future<List<FocusSession>> getFocusSessions() async {
    final now = DateTime.now();
    return [
      FocusSession(
        id: 'demo-fs-1',
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: now.subtract(const Duration(hours: 3, minutes: 35)),
        targetMinutes: 25,
        actualMinutes: 25,
        isCompleted: true,
        title: 'Science Quest',
        category: 'Education',
      ),
      FocusSession(
        id: 'demo-fs-2',
        startTime: now.subtract(const Duration(hours: 2)),
        endTime: now.subtract(const Duration(hours: 1, minutes: 40)),
        targetMinutes: 20,
        actualMinutes: 20,
        isCompleted: true,
        title: 'Math Sprint',
        category: 'Education',
      ),
    ];
  }
}
