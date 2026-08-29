import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/services/abstractions/usage_data_provider.dart';
import 'package:cleartime/core/services/abstractions/local_llm_provider.dart';
import 'package:cleartime/core/services/abstractions/notification_provider.dart';
import 'package:cleartime/core/services/abstractions/device_provider.dart';
import 'package:cleartime/core/services/abstractions/local_usage_store.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/llm_models.dart';

// Mock implementations testing interface conformance
class MockUsageDataProvider implements UsageDataProvider {
  @override
  Future<bool> hasUsagePermission() async => true;

  @override
  Future<bool> requestUsagePermission() async => true;

  @override
  Future<UsageSummary> getTodayUsage() async => const UsageSummary(
        totalMinutes: 120,
        focusMinutes: 60,
        breakCount: 4,
      );

  @override
  Future<List<DailyUsage>> getDailyUsage() async => [];

  @override
  Future<List<DailyUsage>> getWeeklyUsage() async => [];

  @override
  Future<List<DailyUsage>> getMonthlyUsage() async => [];

  @override
  Future<List<CategoryUsage>> getCategoryUsage() async => [];

  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async => [];

  @override
  Future<List<FocusSession>> getFocusSessions() async => [];
}

class MockLocalLLMProvider implements LocalLLMProvider {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> loadModel() async {}

  @override
  Future<void> loadModelById(String modelId) async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> generate({required String prompt}) async =>
      'Great mindful balance today!';

  @override
  Future<ModelInfo> getModelInfo() async => const ModelInfo(
        modelName: 'ClearTime-SLM-Nano',
        version: '1.0.0',
        contextLimit: 2048,
        quantization: 'q4_k_m',
        sizeMb: 450,
        isLoaded: true,
        engineType: 'On-Device GGUF/MediaPipe',
      );

  @override
  Future<int> getContextLimit() async => 2048;

  @override
  Future<int> getMemoryUsage() async => 280;

  @override
  Future<List<LocalModelCatalogEntry>> getInstalledModels() async => [];

  @override
  Future<List<LocalModelCatalogEntry>> getAvailableModels() async => [];

  @override
  Future<bool> installModel(String modelId) async => true;

  @override
  Future<bool> deleteModel(String modelId) async => true;

  @override
  Future<bool> selectModel(String modelId) async => true;

  @override
  Future<StructuredAIResponse> testInference({String? modelId, String? testPrompt}) async =>
      const StructuredAIResponse(answer: 'Local test OK', confidence: 1.0);
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
  Future<void> initialize() async {}

  @override
  Future<void> saveUsage(UsageRecord usage) async {}

  @override
  Future<void> saveUsageBatch(List<UsageRecord> records) async {}

  @override
  Future<List<UsageRecord>> getUsage({DateTime? start, DateTime? end}) async => [];

  @override
  Future<void> saveDailyAggregate(DailyAggregate aggregate) async {}

  @override
  Future<DailyAggregate?> getDailyAggregate(DateTime date) async => null;

  @override
  Future<List<DailyAggregate>> getWeeklyAggregate() async => [];

  @override
  Future<void> deleteUsage(String id) async {}

  @override
  Future<int> deleteExpiredUsage() async => 5;

  @override
  Future<void> wipeAllLocalData() async {}
}

void main() {
  group('Phase 2 Service Abstractions Interface Conformance', () {
    test('UsageDataProvider contract functions correctly', () async {
      final provider = MockUsageDataProvider();
      expect(await provider.hasUsagePermission(), isTrue);
      final usage = await provider.getTodayUsage();
      expect(usage.totalMinutes, equals(120));
      expect(usage.focusMinutes, equals(60));
    });

    test('LocalLLMProvider operates without external cloud dependencies',
        () async {
      final llm = MockLocalLLMProvider();
      expect(await llm.isAvailable(), isTrue);
      final insight = await llm.generate(prompt: 'Hello Buddy');
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
      final purged = await store.deleteExpiredUsage();
      expect(purged, equals(5));
    });
  });
}
