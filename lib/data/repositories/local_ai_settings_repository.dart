import '../models/llm_models.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class LocalAISettingsRepository {
  Future<AISettings> getSettings();
  Future<void> saveSettings(AISettings settings);
  Future<void> updateSettings(AISettings settings);
  Future<void> setAiEnabled(bool enabled);
  Future<void> setActiveModelId(String modelId);
  Future<void> resetToDefaults();
}

/// Encrypted on-device persistence for AI settings.
class EncryptedLocalAISettingsRepository implements LocalAISettingsRepository {
  static const _settingsKey = 'active_settings';

  final EncryptedDeviceStore _store;

  EncryptedLocalAISettingsRepository({required EncryptedDeviceStore store})
      : _store = store;

  @override
  Future<AISettings> getSettings() async {
    final json = await _store.getJson(
      EncryptedDeviceStore.aiSettingsBox,
      _settingsKey,
    );
    if (json == null) return const AISettings();
    try {
      return AISettings.fromJson(json);
    } catch (_) {
      return const AISettings();
    }
  }

  @override
  Future<void> saveSettings(AISettings settings) async {
    await _store.putJson(
      EncryptedDeviceStore.aiSettingsBox,
      _settingsKey,
      settings.toJson(),
    );
  }

  @override
  Future<void> updateSettings(AISettings settings) => saveSettings(settings);

  @override
  Future<void> setAiEnabled(bool enabled) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(isAiEnabled: enabled));
  }

  @override
  Future<void> setActiveModelId(String modelId) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(activeModelId: modelId));
  }

  @override
  Future<void> resetToDefaults() => saveSettings(const AISettings());
}
