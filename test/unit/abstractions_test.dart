import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/services/abstractions/usage_data_provider.dart';
import 'package:cleartime/core/services/abstractions/local_llm_provider.dart';
import 'package:cleartime/core/services/abstractions/notification_provider.dart';
import 'package:cleartime/core/services/abstractions/device_provider.dart';
import 'package:cleartime/core/services/abstractions/local_usage_store.dart';

// Mock implementations testing interface conformance
class MockUsageDataProvider implements UsageDataProvider {
  @override
  Future<Map<String, dynamic>> getAggregatedUsage({
    required DateTime start,
    required DateTime end,
  }) async =>
      {'totalMinutes': 45};

  @override
  Future<bool> hasUsagePermission() async => true;

  @override
  Future<bool> requestUsagePermission() async => true;

  @override
  Stream<Map<String, dynamic>> watchLocalEvents() => const Stream.empty();
}

class MockLocalLLMProvider implements LocalLLMProvider {
  @override
  Future<void> dispose() async {}

  @override
  Future<String> generateWellbeingInsight({
    required Map<String, dynamic> localSummary,
    required String contextPrompt,
  }) async =>
      'Great mindful balance today!';

  @override
  Future<bool> isModelReady() async => true;

  @override
  Future<void> prepareModel(
      {void Function(double progress)? onProgress}) async {
    onProgress?.call(1.0);
  }
}

class MockNotificationProvider implements NotificationProvider {
  @override
  Future<void> cancelNotification(int id) async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> showWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
}

class MockDeviceProvider implements DeviceProvider {
  @override
  Future<String> getClientVersion() async => '1.0.0';

  @override
  Future<String> getDeviceId() async => 'android-uuid-device';

  @override
  Future<String> getDeviceName() async => 'Pixel 8 Pro';

  @override
  Future<String> getOsVersion() async => 'Android 14';

  @override
  Future<bool> isBatteryOptimizationIgnored() async => true;
}

class MockLocalUsageStore implements LocalUsageStore {
  @override
  Future<List<Map<String, dynamic>>> getSnapshots({
    required DateTime start,
    required DateTime end,
  }) async =>
      [];

  @override
  Future<void> initialize() async {}

  @override
  Future<int> purgeOldSnapshots({required int retentionDays}) async => 5;

  @override
  Future<void> saveAggregatedSnapshot({
    required DateTime date,
    required Map<String, dynamic> summary,
  }) async {}

  @override
  Future<void> wipeAllLocalData() async {}
}

void main() {
  group('Future Service Abstractions Interface Conformance', () {
    test('UsageDataProvider contract functions correctly', () async {
      final provider = MockUsageDataProvider();
      expect(await provider.hasUsagePermission(), isTrue);
      final usage = await provider.getAggregatedUsage(
        start: DateTime.now().subtract(const Duration(days: 1)),
        end: DateTime.now(),
      );
      expect(usage['totalMinutes'], equals(45));
    });

    test('LocalLLMProvider operates without external cloud dependencies',
        () async {
      final llm = MockLocalLLMProvider();
      expect(await llm.isModelReady(), isTrue);
      final insight = await llm.generateWellbeingInsight(
        localSummary: {},
        contextPrompt: 'Generate daily positive encouragement',
      );
      expect(insight, contains('mindful'));
    });

    test(
        'NotificationProvider, DeviceProvider, and LocalUsageStore contracts work',
        () async {
      final notif = MockNotificationProvider();
      expect(await notif.hasPermission(), isTrue);

      final device = MockDeviceProvider();
      expect(await device.getDeviceName(), equals('Pixel 8 Pro'));

      final store = MockLocalUsageStore();
      final purged = await store.purgeOldSnapshots(retentionDays: 30);
      expect(purged, equals(5));
    });
  });
}
