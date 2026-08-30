/// Safe Template Engine for On-Device SLM Prompts.
///
/// Treats prompts strictly as inert data templates.
/// Does NOT support code execution, dynamic eval, or script injection.
class PromptTemplateEngine {
  const PromptTemplateEngine();

  /// Whitelist of supported template variables.
  static const Set<String> supportedVariables = {
    'child_name',
    'screen_time',
    'previous_screen_time',
    'usage_change',
    'focus_time',
    'top_category',
    'goal_progress',
    'achievement',
    'break_count',
    'completed_missions',
    'report_date',
    'active_goals',
  };

  /// Disallowed malicious syntax patterns.
  static final RegExp _forbiddenSyntax = RegExp(
    r'(\{\{\s*(eval|execute|code|script|system|import|run|process)\b|\$\{)',
    caseSensitive: false,
  );

  /// Regex pattern to extract {{variable_name}} tokens.
  static final RegExp _variablePattern = RegExp(r'\{\{\s*([a-zA-Z0-9_]+)\s*\}\}');

  /// Extracts all variable names found in the prompt template.
  List<String> extractVariables(String template) {
    final matches = _variablePattern.allMatches(template);
    final vars = <String>{};
    for (final m in matches) {
      final name = m.group(1);
      if (name != null) {
        vars.add(name);
      }
    }
    return vars.toList();
  }

  /// Validates template safety and variable compatibility.
  TemplateValidationResult validateTemplate(String template) {
    if (template.trim().isEmpty) {
      return const TemplateValidationResult(
        isValid: false,
        errorMessage: 'Prompt template cannot be empty.',
      );
    }

    if (_forbiddenSyntax.hasMatch(template)) {
      return const TemplateValidationResult(
        isValid: false,
        errorMessage:
            'Security violation: Code execution or dynamic script expressions are strictly disallowed.',
      );
    }

    final foundVariables = extractVariables(template);
    final unsupported = foundVariables
        .where((v) => !supportedVariables.contains(v))
        .toList();

    if (unsupported.isNotEmpty) {
      return TemplateValidationResult(
        isValid: false,
        errorMessage:
            'Unsupported variable(s) found: ${unsupported.map((e) => "{{$e}}").join(", ")}. Supported variables: ${supportedVariables.map((e) => "{{$e}}").join(", ")}',
        unsupportedVariables: unsupported,
      );
    }

    return TemplateValidationResult(
      isValid: true,
      foundVariables: foundVariables,
    );
  }

  /// Renders the prompt template safely by substituting variables with provided context values.
  String render(String template, Map<String, dynamic> context) {
    final validation = validateTemplate(template);
    if (!validation.isValid) {
      throw FormatException(
        validation.errorMessage ?? 'Invalid template syntax',
      );
    }

    return template.replaceAllMapped(_variablePattern, (match) {
      final key = match.group(1);
      if (key == null) return '';

      if (context.containsKey(key)) {
        final val = context[key];
        return val != null ? val.toString() : '';
      }

      // Safe default placeholders if context lacks a specific key
      switch (key) {
        case 'child_name':
          return 'your child';
        case 'screen_time':
          return '0 min';
        case 'previous_screen_time':
          return '0 min';
        case 'usage_change':
          return '0%';
        case 'focus_time':
          return '0 min';
        case 'top_category':
          return 'Learning';
        case 'goal_progress':
          return '0%';
        case 'achievement':
          return 'Getting started';
        case 'break_count':
          return '0';
        case 'completed_missions':
          return '0';
        case 'report_date':
          return 'Today';
        case 'active_goals':
          return '0';
        default:
          return '';
      }
    });
  }

  /// Generates a preview with realistic mock variables.
  String generatePreview(String template, {String childName = 'Leo'}) {
    final mockContext = {
      'child_name': childName,
      'screen_time': '2h 15m',
      'previous_screen_time': '2h 40m',
      'usage_change': '-15.6%',
      'focus_time': '45m',
      'top_category': 'Learning & Reading',
      'goal_progress': '75%',
      'achievement': 'Focus Master Badge',
      'break_count': '4',
      'completed_missions': '2',
      'report_date': 'Today',
      'active_goals': '2',
    };

    try {
      return render(template, mockContext);
    } catch (_) {
      return template;
    }
  }
}

class TemplateValidationResult {
  final bool isValid;
  final String? errorMessage;
  final List<String> foundVariables;
  final List<String> unsupportedVariables;

  const TemplateValidationResult({
    required this.isValid,
    this.errorMessage,
    this.foundVariables = const [],
    this.unsupportedVariables = const [],
  });
}
