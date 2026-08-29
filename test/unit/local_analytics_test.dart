import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/achievement_model.dart';
import 'package:cleartime/services/analytics/local_analytics_service.dart';

void main() {
  group('LocalAnalyticsService Deterministic Unit Tests', () {
    const analytics = LocalAnalyticsService();
    final today = DateTime.now();

    final testRecords = [
      UsageRecord(
        id: 'rec-1',
        packageName: 'com.khanacademy',
        appName: 'Khan Academy Kids',
        category: 'Education & Learning',
        startTime: DateTime(today.year, today.month, today.day, 10, 0),
        endTime: DateTime(today.year, today.month, today.day, 10, 30),
        durationSeconds: 1800, // 30 mins
      ),
      UsageRecord(
        id: 'rec-2',
        packageName: 'com.duolingo',
        appName: 'Duolingo',
        category: 'Education & Learning',
        startTime: DateTime(today.year, today.month, today.day, 11, 0),
        endTime: DateTime(today.year, today.month, today.day, 11, 25),
        durationSeconds: 1500, // 25 mins
      ),
      UsageRecord(
        id: 'rec-3',
        packageName: 'com.sketch.art',
        appName: 'Drawing Studio',
        category: 'Creativity & Art',
        startTime: DateTime(today.year, today.month, today.day, 14, 0),
        endTime: DateTime(today.year, today.month, today.day, 14, 20),
        durationSeconds: 1200, // 20 mins
      ),
      UsageRecord(
        id: 'rec-4',
        packageName: 'com.game.minecraft',
        appName: 'Minecraft',
        category: 'Games & Play',
        startTime: DateTime(today.year, today.month, today.day, 16, 0),
        endTime: DateTime(today.year, today.month, today.day, 16, 45),
        durationSeconds: 2700, // 45 mins
      ),
    ];

    test('calculateDailyUsage accurately aggregates total minutes and focus minutes', () {
      final daily = analytics.calculateDailyUsage(
        records: testRecords,
        date: today,
        unlockCount: 15,
      );

      // Total = 30 + 25 + 20 + 45 = 120 minutes (2h)
      expect(daily.totalMinutes, equals(120));
      // Focus minutes (Education + Creativity) = 30 + 25 + 20 = 75 minutes
      expect(daily.focusMinutes, equals(75));
      expect(daily.unlockCount, equals(15));
      expect(daily.topApps.length, equals(4));
      expect(daily.topApps.first.appName, equals('Minecraft'));
    });

    test('calculateCategoryBreakdown computes percentages and app counts', () {
      final categories = analytics.calculateCategoryBreakdown(testRecords);

      expect(categories.length, equals(3));
      // Education (55 mins) -> 55/120 = 45.8%
      final educationCat = categories.firstWhere((c) => c.category.contains('Education'));
      expect(educationCat.totalMinutes, equals(55));
      expect(educationCat.appCount, equals(2));
      expect(educationCat.percentage, closeTo(45.8, 0.2));
    });

    test('calculateUsageChange calculates positive and negative differences correctly', () {
      // 100 mins today vs 125 mins yesterday = -20%
      final reduction = analytics.calculateUsageChange(100, 125);
      expect(reduction, equals(-20.0));

      // 150 mins today vs 100 mins yesterday = +50%
      final increase = analytics.calculateUsageChange(150, 100);
      expect(increase, equals(50.0));

      // Zero baseline edge case
      expect(analytics.calculateUsageChange(50, 0), equals(100.0));
      expect(analytics.calculateUsageChange(0, 0), equals(0.0));
    });

    test('calculateFocusTime sums only completed focus sessions', () {
      final sessions = [
        FocusSession(
          id: 'fs-1',
          startTime: today.subtract(const Duration(hours: 3)),
          endTime: today.subtract(const Duration(hours: 2, minutes: 35)),
          targetMinutes: 25,
          actualMinutes: 25,
          isCompleted: true,
        ),
        FocusSession(
          id: 'fs-2',
          startTime: today.subtract(const Duration(hours: 1)),
          endTime: today.subtract(const Duration(minutes: 50)),
          targetMinutes: 20,
          actualMinutes: 10,
          isCompleted: false, // Abandoned
        ),
      ];

      final totalFocus = analytics.calculateFocusTime(sessions);
      expect(totalFocus, equals(25));
    });

    test('calculateBreakFrequency counts gaps > 5 mins between usage sessions', () {
      final timeline = [
        UsageTimelineEntry(
          packageName: 'com.app1',
          appName: 'App 1',
          category: 'Learning',
          startTime: DateTime(today.year, today.month, today.day, 10, 0),
          endTime: DateTime(today.year, today.month, today.day, 10, 20),
          durationMinutes: 20,
        ),
        // Gap of 10 mins (10:20 to 10:30) -> Break 1
        UsageTimelineEntry(
          packageName: 'com.app2',
          appName: 'App 2',
          category: 'Learning',
          startTime: DateTime(today.year, today.month, today.day, 10, 30),
          endTime: DateTime(today.year, today.month, today.day, 10, 50),
          durationMinutes: 20,
        ),
        // Gap of 2 mins (10:50 to 10:52) -> No break
        UsageTimelineEntry(
          packageName: 'com.app3',
          appName: 'App 3',
          category: 'Learning',
          startTime: DateTime(today.year, today.month, today.day, 10, 52),
          endTime: DateTime(today.year, today.month, today.day, 11, 10),
          durationMinutes: 18,
        ),
        // Gap of 30 mins (11:10 to 11:40) -> Break 2
        UsageTimelineEntry(
          packageName: 'com.app4',
          appName: 'App 4',
          category: 'Learning',
          startTime: DateTime(today.year, today.month, today.day, 11, 40),
          endTime: DateTime(today.year, today.month, today.day, 12, 0),
          durationMinutes: 20,
        ),
      ];

      final breaks = analytics.calculateBreakFrequency(timeline);
      expect(breaks, equals(2));
    });

    test('calculateUsageTrend detects decreasing, increasing, and stable patterns', () {
      final decreasingWeek = List.generate(
        7,
        (i) => DailyUsage(
          date: today.subtract(Duration(days: 6 - i)),
          totalMinutes: 200 - (i * 15), // 200 down to 110
        ),
      );
      expect(analytics.calculateUsageTrend(decreasingWeek), equals('decreasing'));

      final increasingWeek = List.generate(
        7,
        (i) => DailyUsage(
          date: today.subtract(Duration(days: 6 - i)),
          totalMinutes: 100 + (i * 20), // 100 up to 220
        ),
      );
      expect(analytics.calculateUsageTrend(increasingWeek), equals('increasing'));
    });

    test('evaluateAchievementCriteria accurately checks badge conditions', () {
      expect(
        analytics.evaluateAchievementCriteria(
          type: AchievementType.focusStarter,
          focusMinutes: 25,
          breakCount: 2,
          consecutiveDaysGoalMet: 1,
          maxSingleFocusSession: 25,
        ),
        isTrue,
      );

      expect(
        analytics.evaluateAchievementCriteria(
          type: AchievementType.breakMaster,
          focusMinutes: 50,
          breakCount: 5,
          consecutiveDaysGoalMet: 3,
          maxSingleFocusSession: 20,
        ),
        isTrue,
      );

      expect(
        analytics.evaluateAchievementCriteria(
          type: AchievementType.sevenDayBalance,
          focusMinutes: 50,
          breakCount: 3,
          consecutiveDaysGoalMet: 6, // Not yet 7
          maxSingleFocusSession: 20,
        ),
        isFalse,
      );
    });
  });
}
