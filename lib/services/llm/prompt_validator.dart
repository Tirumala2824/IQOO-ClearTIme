import '../../data/models/llm_models.dart';
import 'prompt_template_engine.dart';

class PromptValidationResult {
  final bool isValid;
  final List<String> errors;

  const PromptValidationResult({
    required this.isValid,
    this.errors = const [],
  });
}

/// Prompt Validator ensuring safety, size limits, and valid template syntax.
class PromptValidator {
  final PromptTemplateEngine _templateEngine;

  const PromptValidator({
    PromptTemplateEngine templateEngine = const PromptTemplateEngine(),
  }) : _templateEngine = templateEngine;

  /// Validates a prompt before saving or activating.
  PromptValidationResult validate(PromptDefinition prompt) {
    final errors = <String>[];

    if (prompt.name.trim().isEmpty) {
      errors.add('Prompt name cannot be empty.');
    }

    if (prompt.content.trim().isEmpty) {
      errors.add('Prompt content cannot be empty.');
    }

    if (prompt.content.length < 10) {
      errors.add('Prompt content is too short (minimum 10 characters).');
    }

    if (prompt.content.length > 8000) {
      errors.add('Prompt content exceeds safe local context size (max 8,000 characters).');
    }

    if (prompt.version < 1) {
      errors.add('Prompt version must be a positive integer.');
    }

    final templateResult = _templateEngine.validateTemplate(prompt.content);
    if (!templateResult.isValid && templateResult.errorMessage != null) {
      errors.add(templateResult.errorMessage!);
    }

    // Role-specific persona checks
    if (prompt.type == PromptType.childInsight ||
        prompt.type == PromptType.childMission ||
        prompt.type == PromptType.childReflection) {
      final lower = prompt.content.toLowerCase();
      final punitiveKeywords = [
        'punish',
        'punishment',
        'guilt',
        'shame',
        'bad child',
        'threat',
        'surveillance',
        'spy'
      ];
      for (final keyword in punitiveKeywords) {
        if (lower.contains(keyword)) {
          errors.add(
              'Child prompts must remain positive and encouraging. Disallowed punitive keyword: "$keyword".');
        }
      }
    }

    return PromptValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
    );
  }
}
