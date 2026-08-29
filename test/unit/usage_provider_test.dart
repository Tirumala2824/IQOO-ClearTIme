import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/services/usage/demo_usage_data_provider.dart';

void main() {
  group('UsageDataProvider and Demo Adapter Tests', () {
    test('DemoUsageDataProvider provides rich deterministic usage data', () async {
      final provider = DemoUsageDataProvider(isDynamic: false);
      expect(await provider.hasUsagePermission(), isTrue);

      final today = await provider.getTodayUsage();
      expect(today.totalMinutes, equals(170));
      expect(today.focusMinutes, equals(105));
      expect(today.breakCount, equals(5));
      expect(today.categories.length, equals(4));
      expect(today.topApps.isNotEmpty, isTrue);

      final weekly = await provider.getWeeklyUsage();
      expect(weekly.length, equals(7));

      final timeline = await provider.getUsageTimeline();
      expect(timeline.length, equals(3));
      expect(timeline.first.appName, equals('Khan Academy Kids'));

      final focusSessions = await provider.getFocusSessions();
      expect(focusSessions.length, equals(2));
      expect(focusSessions.first.isCompleted, isTrue);
    });

    test('DemoUsageDataProvider respects mock permission toggle', () async {
      final provider = DemoUsageDataProvider();
      provider.setMockPermission(false);
      expect(await provider.hasUsagePermission(), isFalse);

      final emptyToday = await provider.getTodayUsage();
      expect(emptyToday.totalMinutes, equals(0));

      await provider.requestUsagePermission();
      expect(await provider.hasUsagePermission(), isTrue);
    });
  });
}
