import '../../data/models/llm_models.dart';
import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/repositories/local_ai_settings_repository.dart';

/// LocalModelManager manages on-device SLM discovery, installation, activation, unloading, and testing.
///
/// STRICT PRIVACY INVARIANT:
/// Models are stored locally on device storage and executed entirely offline.
/// No remote inference dependencies or cloud fallback.
class LocalModelManager {
  final LocalLLMProvider _llmProvider;
  final LocalAISettingsRepository _settingsRepo;

  LocalModelManager({
    required LocalLLMProvider llmProvider,
    required LocalAISettingsRepository settingsRepo,
  })  : _llmProvider = llmProvider,
        _settingsRepo = settingsRepo;

  /// Retrieves list of all locally installed models.
  Future<List<LocalModelCatalogEntry>> getInstalledModels() async {
    final models = await _llmProvider.getInstalledModels();
    final settings = await _settingsRepo.getSettings();

    return models.map((m) {
      return m.copyWith(isActive: m.id == settings.activeModelId);
    }).toList();
  }

  /// Retrieves list of available models ready for local installation.
  Future<List<LocalModelCatalogEntry>> getAvailableModels() async {
    return await _llmProvider.getAvailableModels();
  }

  /// Selects and switches active on-device model.
  Future<bool> selectModel(String modelId) async {
    final success = await _llmProvider.selectModel(modelId);
    if (success) {
      await _settingsRepo.setActiveModelId(modelId);
    }
    return success;
  }

  /// Installs an available model locally into device storage.
  Future<bool> installModel(String modelId) async {
    return await _llmProvider.installModel(modelId);
  }

  /// Deletes an installed model asset from device storage.
  Future<bool> deleteModel(String modelId) async {
    final settings = await _settingsRepo.getSettings();
    if (settings.activeModelId == modelId) {
      // Clear the active selection rather than pointing at a fabricated
      // default model.
      await _settingsRepo.setActiveModelId('');
    }
    return await _llmProvider.deleteModel(modelId);
  }

  /// Unloads the active model from RAM to free system memory.
  Future<void> unloadModel() async {
    await _llmProvider.unloadModel();
  }

  /// Runs an on-device local test inference to verify model integrity.
  Future<StructuredAIResponse> testModel({
    String? modelId,
    String? testPrompt,
  }) async {
    return await _llmProvider.testInference(
      modelId: modelId,
      testPrompt: testPrompt ??
          'Evaluate 120 minutes screen time with 45 minutes focused learning.',
    );
  }
}
