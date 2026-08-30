import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/services/abstractions/local_llm_provider.dart';
import 'package:cleartime/data/models/llm_models.dart';
import 'package:cleartime/data/repositories/local_ai_settings_repository.dart';
import 'package:cleartime/services/llm/local_model_manager.dart';
import 'package:cleartime/services/storage/encrypted_device_store.dart';

import '../helpers/encrypted_store_helper.dart';

/// In-memory fake of the on-device model provider. The production
/// [OnDeviceLLMProvider] now depends on the native GGUF runtime and signed
/// distribution manifest, so catalog operations are faked here.
class _FakeLLMProvider implements LocalLLMProvider {
  final Map<String, LocalModelCatalogEntry> _installed = {};
  bool _loaded = true;

  _FakeLLMProvider() {
    _installed['slm-nano-380m'] = _entry('slm-nano-380m', isInstalled: true);
    _installed['slm-balanced-1b'] =
        _entry('slm-balanced-1b', isInstalled: true);
  }

  static LocalModelCatalogEntry _entry(String id, {bool isInstalled = false}) {
    return LocalModelCatalogEntry(
      id: id,
      name: id,
      version: '1.0.0',
      sizeDescription: '~1.2 GB',
      sizeMb: 1200,
      contextTokens: 4096,
      quantization: 'q4_k_m',
      compatibility: 'Local device storage',
      isInstalled: isInstalled,
      description: 'On-device SLM for offline inference.',
    );
  }

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> loadModel() async => _loaded = true;

  @override
  Future<void> loadModelById(String modelId) async => _loaded = true;

  @override
  Future<void> unloadModel() async => _loaded = false;

  @override
  Future<String> generate({required String prompt}) async =>
      '{"answer":"On-device benchmark answer.",'
      '"observations":["Inference completed"],'
      '"evidence":["Local model"],"recommendations":[],"confidence":0.95}';

  @override
  Future<ModelInfo> getModelInfo() async => ModelInfo(
        modelName: 'ClearTime-SLM-Nano',
        version: '1.0.0',
        contextLimit: 4096,
        quantization: 'q4_k_m',
        sizeMb: 1200,
        isLoaded: _loaded,
      );

  @override
  Future<int> getContextLimit() async => 4096;

  @override
  Future<int> getMemoryUsage() async => 280;

  @override
  Future<List<LocalModelCatalogEntry>> getInstalledModels() async =>
      _installed.values.toList();

  @override
  Future<List<LocalModelCatalogEntry>> getAvailableModels() async =>
      ['slm-nano-380m', 'slm-balanced-1b', 'slm-pro-3b']
          .map((id) => _entry(id, isInstalled: _installed.containsKey(id)))
          .toList();

  @override
  Future<bool> installModel(String modelId) async {
    _installed[modelId] = _entry(modelId, isInstalled: true);
    return true;
  }

  @override
  Future<bool> deleteModel(String modelId) async {
    if (!_installed.containsKey(modelId)) return false;
    _installed.remove(modelId);
    return true;
  }

  @override
  Future<bool> selectModel(String modelId) async =>
      _installed.containsKey(modelId);

  @override
  Future<StructuredAIResponse> testInference({
    String? modelId,
    String? testPrompt,
  }) async =>
      const StructuredAIResponse(
        answer: 'Local inference completed within 320 ms.',
        observations: ['Runtime ready', 'Inference completed'],
        evidence: ['Local model benchmark'],
        recommendations: ['On-device inference verified.'],
        confidence: 0.95,
        isFallback: false,
      );
}

void main() {
  group('LocalModelManager Unit Tests', () {
    late LocalModelManager manager;
    late _FakeLLMProvider llmProvider;
    late LocalAISettingsRepository settingsRepo;

    setUp(() async {
      final store = await createTestDeviceStore();
      // Hive boxes are process-global across tests in this file, so reset the
      // settings box for deterministic default settings in each test.
      await store.clearBox(EncryptedDeviceStore.aiSettingsBox);
      llmProvider = _FakeLLMProvider();
      settingsRepo = EncryptedLocalAISettingsRepository(store: store);
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

    test('Deletes an installed model asset and clears the active model if deleted', () async {
      await manager.installModel('slm-pro-3b');
      await manager.selectModel('slm-pro-3b');

      final deleteSuccess = await manager.deleteModel('slm-pro-3b');
      expect(deleteSuccess, isTrue);

      // Deleting the active model clears the active selection instead of
      // fabricating a default pointer.
      final settings = await settingsRepo.getSettings();
      expect(settings.activeModelId, isEmpty);
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
