import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/llm_models.dart';
import 'package:cleartime/data/repositories/local_prompt_repository.dart';

void main() {
  group('LocalPromptRepository & PromptManager Unit Tests', () {
    late LocalPromptRepository repo;

    setUp(() {
      repo = InMemoryLocalPromptRepository();
    });

    test('Loads 6 default prompt categories on initialization', () async {
      final prompts = await repo.getAllPrompts();
      expect(prompts.length, greaterThanOrEqualTo(6));

      final types = prompts.map((p) => p.type).toSet();
      expect(types, contains(PromptType.childInsight));
      expect(types, contains(PromptType.childMission));
      expect(types, contains(PromptType.childReflection));
      expect(types, contains(PromptType.parentReport));
      expect(types, contains(PromptType.parentChat));
      expect(types, contains(PromptType.parentTriggerExplanation));
    });

    test('Saving prompt modifications creates a new version without overwriting history', () async {
      final initial = await repo.getPromptById('prompt-child-insight');
      expect(initial, isNotNull);
      expect(initial!.version, equals(1));

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
      final initial = await repo.getPromptById('prompt-child-insight');
      final originalContent = initial!.content;

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
      final duplicated = await repo.duplicatePrompt('prompt-child-mission');

      expect(duplicated.id, isNot(equals('prompt-child-mission')));
      expect(duplicated.name, contains('Copy'));
      expect(duplicated.version, equals(1));
      expect(duplicated.isActive, isFalse);

      final allPrompts = await repo.getAllPrompts();
      expect(allPrompts.any((p) => p.id == duplicated.id), isTrue);
    });

    test('Activating a prompt marks other prompts of same type inactive', () async {
      final duplicate = await repo.duplicatePrompt('prompt-child-insight');
      await repo.activatePrompt(duplicate.id);

      final activePrompt = await repo.getActivePromptByType(PromptType.childInsight);
      expect(activePrompt?.id, equals(duplicate.id));
      expect(activePrompt?.isActive, isTrue);

      final original = await repo.getPromptById('prompt-child-insight');
      expect(original?.isActive, isFalse);
    });

    test('Reset to default restores original template content', () async {
      final original = await repo.getPromptById('prompt-parent-report');
      await repo.savePrompt(
        original!.copyWith(content: 'Temporary experimental text'),
      );

      final reset = await repo.resetToDefault(PromptType.parentReport);
      expect(reset.content, contains('Analyze the approved summary facts'));
    });
  });
}
