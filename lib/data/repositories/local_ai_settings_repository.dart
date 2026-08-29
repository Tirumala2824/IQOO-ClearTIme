import '../models/llm_models.dart';

abstract class LocalAISettingsRepository {
  Future<AISettings> getSettings();
  Future<void> saveSettings(AISettings settings);
  Future<void> setAiEnabled(bool enabled);
  Future<void> setActiveModelId(String modelId);
  Future<void> resetToDefaults();
}

class InMemoryLocalAISettingsRepository implements LocalAISettingsRepository {
  AISettings _settings;

  InMemoryLocalAISettingsRepository({AISettings? initialSettings})
      : _settings = initialSettings ?? const AISettings();

  @override
  Future<AISettings> getSettings() async {
    return _settings;
  }

  @override
  Future<void> saveSettings(AISettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> setAiEnabled(bool enabled) async {
    _settings = _settings.copyWith(isAiEnabled: enabled);
  }

  @override
  Future<void> setActiveModelId(String modelId) async {
    _settings = _settings.copyWith(activeModelId: modelId);
  }

  @override
  Future<void> resetToDefaults() async {
    _settings = const AISettings();
  }
}
