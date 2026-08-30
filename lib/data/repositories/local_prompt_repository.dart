import '../models/llm_models.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class LocalPromptRepository {
  Future<List<PromptDefinition>> getAllPrompts();
  Future<PromptDefinition?> getPromptById(String id);
  Future<PromptDefinition?> getActivePromptByType(PromptType type);
  Future<PromptDefinition> savePrompt(PromptDefinition prompt, {String changeNotes = ''});
  Future<void> activatePrompt(String id);
  Future<void> deactivatePrompt(String id);
  Future<PromptDefinition> duplicatePrompt(String id);
  Future<void> resetToDefault(PromptType type);
  Future<void> resetAllToDefaults();
  Future<List<PromptVersion>> getVersionHistory(String promptId);
  Future<PromptDefinition> rollbackToVersion(String promptId, int targetVersion);
}

/// Encrypted on-device persistence for AI prompt templates.
///
/// The store starts empty: no factory prompts are seeded. Templates enter
/// only through explicit parent authoring, and resets clear stored state
/// instead of restoring fabricated defaults.
class EncryptedLocalPromptRepository implements LocalPromptRepository {
  final EncryptedDeviceStore _store;

  EncryptedLocalPromptRepository({required EncryptedDeviceStore store})
      : _store = store;

  String _versionKey(String promptId, int version) => '$promptId:v$version';

  @override
  Future<List<PromptDefinition>> getAllPrompts() async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.promptsBox,
      onCorrupt: (key, _) => _store.delete(EncryptedDeviceStore.promptsBox, key),
    );
    final prompts = <PromptDefinition>[];
    for (final json in jsons) {
      try {
        prompts.add(PromptDefinition.fromJson(json));
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    prompts.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return prompts;
  }

  @override
  Future<PromptDefinition?> getPromptById(String id) async {
    final json = await _store.getJson(EncryptedDeviceStore.promptsBox, id);
    if (json == null) return null;
    try {
      return PromptDefinition.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PromptDefinition?> getActivePromptByType(PromptType type) async {
    final prompts = await getAllPrompts();
    try {
      return prompts.firstWhere((p) => p.type == type && p.isActive);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PromptDefinition> savePrompt(
    PromptDefinition prompt, {
    String changeNotes = '',
  }) async {
    final existing = await getPromptById(prompt.id);
    final newVersion = (existing?.version ?? 0) + 1;
    final now = DateTime.now();

    final updated = prompt.copyWith(
      version: newVersion,
      updatedAt: now,
    );

    await _store.putJson(
      EncryptedDeviceStore.promptsBox,
      prompt.id,
      updated.toJson(),
    );

    final history = await getVersionHistory(prompt.id);
    history.add(
      PromptVersion(
        promptId: prompt.id,
        version: newVersion,
        content: prompt.content,
        createdAt: now,
        changeNotes: changeNotes.isNotEmpty ? changeNotes : 'Updated version $newVersion',
      ),
    );
    await _store.putJson(
      EncryptedDeviceStore.promptVersionsBox,
      _versionKey(prompt.id, newVersion),
      history.last.toJson(),
    );

    return updated;
  }

  @override
  Future<void> activatePrompt(String id) async {
    final target = await getPromptById(id);
    if (target == null) return;

    final prompts = await getAllPrompts();
    for (final p in prompts) {
      if (p.type == target.type && p.id != id && p.isActive) {
        await _store.putJson(
          EncryptedDeviceStore.promptsBox,
          p.id,
          p.copyWith(isActive: false).toJson(),
        );
      }
    }
    await _store.putJson(
      EncryptedDeviceStore.promptsBox,
      id,
      target.copyWith(isActive: true).toJson(),
    );
  }

  @override
  Future<void> deactivatePrompt(String id) async {
    final target = await getPromptById(id);
    if (target != null) {
      await _store.putJson(
        EncryptedDeviceStore.promptsBox,
        id,
        target.copyWith(isActive: false).toJson(),
      );
    }
  }

  @override
  Future<PromptDefinition> duplicatePrompt(String id) async {
    final original = await getPromptById(id);
    if (original == null) {
      throw ArgumentError('Prompt not found: $id');
    }

    final newId = 'prompt-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final duplicate = original.copyWith(
      id: newId,
      name: '${original.name} (Copy)',
      version: 1,
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );

    await _store.putJson(
      EncryptedDeviceStore.promptsBox,
      newId,
      duplicate.toJson(),
    );

    await _store.putJson(
      EncryptedDeviceStore.promptVersionsBox,
      _versionKey(newId, 1),
      PromptVersion(
        promptId: newId,
        version: 1,
        content: duplicate.content,
        createdAt: now,
        changeNotes: 'Duplicated from ${original.name}',
      ).toJson(),
    );

    return duplicate;
  }

  @override
  Future<void> resetToDefault(PromptType type) async {
    // There are no seeded factory prompts: a "reset" removes stored custom
    // templates for the type so consumers see a truthful empty state.
    final prompts = await getAllPrompts();
    for (final p in prompts.where((p) => p.type == type)) {
      await _store.delete(EncryptedDeviceStore.promptsBox, p.id);
    }
  }

  @override
  Future<void> resetAllToDefaults() async {
    await _store.clearBox(EncryptedDeviceStore.promptsBox);
    await _store.clearBox(EncryptedDeviceStore.promptVersionsBox);
  }

  @override
  Future<List<PromptVersion>> getVersionHistory(String promptId) async {
    final versions = <PromptVersion>[];
    final jsons = await _store.getAllJson(EncryptedDeviceStore.promptVersionsBox);
    for (final json in jsons) {
      try {
        final version = PromptVersion.fromJson(json);
        if (version.promptId == promptId) versions.add(version);
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    versions.sort((a, b) => a.version.compareTo(b.version));
    return versions;
  }

  @override
  Future<PromptDefinition> rollbackToVersion(String promptId, int targetVersion) async {
    final prompt = await getPromptById(promptId);
    if (prompt == null) {
      throw ArgumentError('Prompt not found: $promptId');
    }

    final history = await getVersionHistory(promptId);
    final historical = history.firstWhere(
      (v) => v.version == targetVersion,
      orElse: () => throw ArgumentError('Version $targetVersion not found for prompt $promptId'),
    );

    return savePrompt(
      prompt.copyWith(content: historical.content),
      changeNotes: 'Rolled back to v$targetVersion',
    );
  }
}