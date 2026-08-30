import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/llm_models.dart';
import 'package:cleartime/data/repositories/local_prompt_repository.dart';
import 'package:cleartime/services/storage/encrypted_device_store.dart';

import '../helpers/encrypted_store_helper.dart';

void main() {
  group('LocalPromptRepository Unit Tests', () {
    late LocalPromptRepository repo;
    late EncryptedDeviceStore store;

    setUp(() async {
      store = await createTestDeviceStore();
      // The encrypted store starts empty and Hive boxes are process-global,
      // so clear the boxes this suite uses for deterministic per-test state.
      await store.clearBox(EncryptedDeviceStore.promptsBox);
      await store.clearBox(EncryptedDeviceStore.promptVersionsBox);
      repo = EncryptedLocalPromptRepository(store: store);
    });

    test('Saves and loads one prompt template per supported category', () async {
      // The encrypted store starts empty: tests seed their own fixtures.
      for (final type in PromptType.values) {
        await repo.savePrompt(
          samplePrompt(id: 'prompt-${type.name}', type: type),
        );
      }

      final prompts = await repo.getAllPrompts();
      expect(prompts.length, equals(6));

      final types = prompts.map((p) => p.type).toSet();
      expect(types, contains(PromptType.childInsight));
      expect(types, contains(PromptType.childMission));
      expect(types, contains(PromptType.childReflection));
      expect(types, contains(PromptType.parentReport));
      expect(types, contains(PromptType.parentChat));
      expect(types, contains(PromptType.parentTriggerExplanation));
    });

    test('Saving prompt modifications creates a new version without overwriting history', () async {
      final initial = await repo.savePrompt(
        samplePrompt(id: 'prompt-child-insight'),
      );
      expect(initial.version, equals(1));

      final updated = await repo.savePrompt(
        initial.copyWith(content: 'New modified content for {{child_name}} with {{focus_time}} focus.'),
        changeNotes: 'Added clearer focus reminder',
      );

      expect(updated.version, equals(2));

      final history = await repo.getVersionHistory('prompt-child-insight');
      expect(history.length, equals(2));
      expect(history[0].version, equals(1));
      expect(history[1].version, equals(2));
      expect(history[1].changeNotes, equals('Added clearer focus reminder'));
    });

    test('Rollback restores content from a previous version and appends new version entry', () async {
      final initial = await repo.savePrompt(
        samplePrompt(id: 'prompt-child-insight'),
      );
      final originalContent = initial.content;

      // Edit 1 -> v2
      await repo.savePrompt(
        initial.copyWith(content: 'Version 2 content for {{child_name}}.'),
        changeNotes: 'v2 edit',
      );

      // Rollback to v1 -> v3
      final rolledBack = await repo.rollbackToVersion('prompt-child-insight', 1);

      expect(rolledBack.version, equals(3));
      expect(rolledBack.content, equals(originalContent));

      final history = await repo.getVersionHistory('prompt-child-insight');
      expect(history.length, equals(3));
    });

    test('Duplicate prompt creates independent template with copy name and v1', () async {
      await repo.savePrompt(
        samplePrompt(id: 'prompt-child-mission', type: PromptType.childMission),
      );
      final duplicated = await repo.duplicatePrompt('prompt-child-mission');

      expect(duplicated.id, isNot(equals('prompt-child-mission')));
      expect(duplicated.name, contains('Copy'));
      expect(duplicated.version, equals(1));
      expect(duplicated.isActive, isFalse);

      final allPrompts = await repo.getAllPrompts();
      expect(allPrompts.any((p) => p.id == duplicated.id), isTrue);
    });

    test('Activating a prompt marks other prompts of same type inactive', () async {
      await repo.savePrompt(
        samplePrompt(id: 'prompt-child-insight'),
      );
      final duplicate = await repo.duplicatePrompt('prompt-child-insight');
      await repo.activatePrompt(duplicate.id);

      final activePrompt = await repo.getActivePromptByType(PromptType.childInsight);
      expect(activePrompt?.id, equals(duplicate.id));
      expect(activePrompt?.isActive, isTrue);

      final original = await repo.getPromptById('prompt-child-insight');
      expect(original?.isActive, isFalse);
    });

    test('Reset to default clears stored templates of that type', () async {
      await repo.savePrompt(
        samplePrompt(id: 'prompt-parent-report', type: PromptType.parentReport),
      );
      final original = await repo.getPromptById('prompt-parent-report');
      expect(original, isNotNull);
      await repo.savePrompt(
        original!.copyWith(content: 'Temporary experimental text'),
      );

      // resetToDefault now clears stored prompts of the type (no seeded
      // factory content exists to restore).
      await repo.resetToDefault(PromptType.parentReport);

      expect(await repo.getPromptById('prompt-parent-report'), isNull);
      final remaining = await repo.getAllPrompts();
      expect(remaining.any((p) => p.type == PromptType.parentReport), isFalse);
    });

    test('Reset all defaults clears every stored prompt template', () async {
      for (final type in PromptType.values) {
        await repo.savePrompt(
          samplePrompt(id: 'prompt-${type.name}', type: type),
        );
      }

      await repo.resetAllToDefaults();

      final prompts = await repo.getAllPrompts();
      expect(prompts, isEmpty);
    });
  });
}