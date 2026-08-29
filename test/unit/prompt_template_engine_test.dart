import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/services/llm/prompt_template_engine.dart';
import 'package:cleartime/services/llm/prompt_validator.dart';
import 'package:cleartime/data/models/llm_models.dart';

void main() {
  group('PromptTemplateEngine Unit Tests', () {
    const engine = PromptTemplateEngine();

    test('Renders template with valid supported variables', () {
      const template =
          'Hello {{child_name}}! You used {{screen_time}} with {{focus_time}} focus. Top category was {{top_category}}.';
      final context = {
        'child_name': 'Leo',
        'screen_time': '2h 10m',
        'focus_time': '50m',
        'top_category': 'Learning',
      };

      final rendered = engine.render(template, context);
      expect(
        rendered,
        equals(
            'Hello Leo! You used 2h 10m with 50m focus. Top category was Learning.'),
      );
    });

    test('Extracts variable list accurately', () {
      const template =
          '{{child_name}} achieved {{goal_progress}} on {{report_date}} after {{break_count}} breaks.';
      final vars = engine.extractVariables(template);

      expect(vars, containsAll(['child_name', 'goal_progress', 'report_date', 'break_count']));
      expect(vars.length, equals(4));
    });

    test('Fails validation when unsupported variables are present', () {
      const template = 'Child spent time on {{unsupported_raw_keystrokes_var}}.';
      final result = engine.validateTemplate(template);

      expect(result.isValid, isFalse);
      expect(result.unsupportedVariables, contains('unsupported_raw_keystrokes_var'));
      expect(result.errorMessage, contains('Unsupported variable(s) found'));
    });

    test('Strictly rejects code execution and script injection expressions', () {
      final maliciousTemplates = [
        '{{eval(1+1)}}',
        '{{execute("rm -rf /")}}',
        '{{code(print("leak"))}}',
        '{{system("cat /etc/passwd")}}',
        r'Child info: ${dangerousCode()}',
      ];

      for (final t in maliciousTemplates) {
        final result = engine.validateTemplate(t);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Security violation'));
      }
    });

    test('Uses safe default placeholders when context variables are missing', () {
      const template = 'Hi {{child_name}}, your screen time was {{screen_time}}.';
      final rendered = engine.render(template, {});

      expect(rendered, contains('Explorer'));
      expect(rendered, contains('0 min'));
    });
  });

  group('PromptValidator Unit Tests', () {
    const validator = PromptValidator();

    test('Validates compliant prompt successfully', () {
      final prompt = PromptDefinition(
        id: 'p-1',
        name: 'Daily Coach',
        type: PromptType.childInsight,
        content: 'Hi {{child_name}}! You had a great focus day with {{focus_time}}.',
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = validator.validate(prompt);
      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('Rejects punitive or surveillance language in child prompts', () {
      final punitivePrompt = PromptDefinition(
        id: 'p-bad',
        name: 'Punitive Prompt',
        type: PromptType.childInsight,
        content: 'You were a bad child today and deserve punishment for screen time.',
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = validator.validate(punitivePrompt);
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('punish'));
    });

    test('Rejects empty or excessively short prompts', () {
      final shortPrompt = PromptDefinition(
        id: 'p-short',
        name: 'Short',
        type: PromptType.parentReport,
        content: 'Hi',
        version: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = validator.validate(shortPrompt);
      expect(result.isValid, isFalse);
      expect(result.errors.first, contains('too short'));
    });
  });
}
