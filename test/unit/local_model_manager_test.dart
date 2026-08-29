import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/services/llm/local_model_manager.dart';
import 'package:cleartime/services/llm/on_device_llm_provider.dart';
import 'package:cleartime/data/repositories/local_ai_settings_repository.dart';

void main() {
  group('LocalModelManager Unit Tests', () {
    late LocalModelManager manager;
    late OnDeviceLLMProvider llmProvider;
    late LocalAISettingsRepository settingsRepo;

    setUp(() {
      llmProvider = OnDeviceLLMProvider();
      settingsRepo = InMemoryLocalAISettingsRepository();
      manager = LocalModelManager(
        llmProvider: llmProvider,
        settingsRepo: settingsRepo,
      );
    });

    test('Retrieves installed models and identifies active model', () async {
      final installed = await manager.getInstalledModels();
      expect(installed, isNotEmpty);
      expect(installed.any((m) => m.id == 'slm-nano-380m'), isTrue);

      final active = installed.firstWhere((m) => m.isActive);
      expect(active.id, equals('slm-nano-380m'));
    });

    test('Retrieves available catalog models ready for installation', () async {
      final available = await manager.getAvailableModels();
      expect(available, isNotEmpty);
      expect(available.any((m) => m.id == 'slm-pro-3b'), isTrue);
    });

    test('Selects and activates a different installed model', () async {
      final success = await manager.selectModel('slm-balanced-1b');
      expect(success, isTrue);

      final settings = await settingsRepo.getSettings();
      expect(settings.activeModelId, equals('slm-balanced-1b'));

      final installed = await manager.getInstalledModels();
      final active = installed.firstWhere((m) => m.isActive);
      expect(active.id, equals('slm-balanced-1b'));
    });

    test('Installs an available model locally into device storage', () async {
      final success = await manager.installModel('slm-pro-3b');
      expect(success, isTrue);

      final installed = await manager.getInstalledModels();
      expect(installed.any((m) => m.id == 'slm-pro-3b' && m.isInstalled), isTrue);
    });

    test('Deletes an installed model asset and resets active model if deleted', () async {
      await manager.installModel('slm-pro-3b');
      await manager.selectModel('slm-pro-3b');

      final deleteSuccess = await manager.deleteModel('slm-pro-3b');
      expect(deleteSuccess, isTrue);

      final settings = await settingsRepo.getSettings();
      expect(settings.activeModelId, equals('slm-nano-380m'));
    });

    test('Executes test benchmark locally without network', () async {
      final result = await manager.testModel(
        modelId: 'slm-nano-380m',
        testPrompt: 'Benchmark test prompt',
      );

      expect(result.answer, isNotEmpty);
      expect(result.confidence, greaterThanOrEqualTo(0.9));
      expect(result.isFallback, isFalse);
      expect(result.observations, isNotEmpty);
    });

    test('Unloads active model to free RAM', () async {
      await manager.unloadModel();
      final info = await llmProvider.getModelInfo();
      expect(info.isLoaded, isFalse);
    });
  });
}
