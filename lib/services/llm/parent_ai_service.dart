import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';
import '../../data/repositories/local_prompt_repository.dart';
import '../../data/repositories/local_ai_settings_repository.dart';
import 'parent_ai_context_builder.dart';
import 'prompt_template_engine.dart';
import 'ai_response_validator.dart';
import 'deterministic_fallback_service.dart';

/// ParentAIService provides objective, privacy-safe report insights for parents.
///
/// STRICT PRIVACY INVARIANT:
/// 1. Only processes approved parent report facts.
/// 2. Raw child timestamps, private reflections, and secret device data are NEVER passed to the LLM.
/// 3. If AI is disabled or fails, DeterministicFallbackService provides fact summaries.
class ParentAIService {
  final LocalLLMProvider _llmProvider;
  final ParentAIContextBuilder _contextBuilder;
  final LocalPromptRepository _promptRepo;
  final LocalAISettingsRepository _settingsRepo;
  final PromptTemplateEngine _templateEngine;
  final AIResponseValidator _responseValidator;
  final DeterministicFallbackService _fallbackService;

  const ParentAIService({
    required LocalLLMProvider llmProvider,
    ParentAIContextBuilder contextBuilder = const ParentAIContextBuilder(),
    required LocalPromptRepository promptRepo,
    required LocalAISettingsRepository settingsRepo,
    PromptTemplateEngine templateEngine = const PromptTemplateEngine(),
    AIResponseValidator responseValidator = const AIResponseValidator(),
    DeterministicFallbackService fallbackService =
        const DeterministicFallbackService(),
  })  : _llmProvider = llmProvider,
        _contextBuilder = contextBuilder,
        _promptRepo = promptRepo,
        _settingsRepo = settingsRepo,
        _templateEngine = templateEngine,
        _responseValidator = responseValidator,
        _fallbackService = fallbackService;

  ParentAIContextBuilder get contextBuilder => _contextBuilder;

  /// Analyzes an approved parent report using local SLM.
  Future<StructuredAIResponse> analyzeReport({
    required ParentAIApprovedReportContext context,
    String? customQuery,
  }) async {
    final settings = await _settingsRepo.getSettings();
    if (!settings.isAiEnabled) {
      return _fallbackService.generateDisabledMessage();
    }

    final isReady = await _llmProvider.isAvailable();
    if (!isReady) {
      return _fallbackService.generateParentFallback(
        context: context,
        query: customQuery,
      );
    }

    try {
      final promptType = customQuery != null
          ? PromptType.parentChat
          : PromptType.parentReport;
      final promptDef =
          await _promptRepo.getActivePromptByType(promptType);

      final template = promptDef?.content ??
          'Analyze approved summary facts for {{child_name}} on {{report_date}}: Screen time {{screen_time}}, Focus {{focus_time}}, Goal progress {{goal_progress}}. Provide an objective summary and habit coaching suggestions.';

      final hours = context.totalScreenMinutes ~/ 60;
      final mins = context.totalScreenMinutes % 60;
      final screenTimeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      final vars = {
        'child_name': context.childNickname,
        'report_date': context.reportDateFormatted,
        'screen_time': screenTimeStr,
        'previous_screen_time': '2h 15m',
        'usage_change':
            '${context.changePercentage >= 0 ? "+" : ""}${context.changePercentage.toStringAsFixed(1)}%',
        'focus_time': '${context.focusMinutes}m',
        'top_category': context.topCategory,
        'goal_progress':
            '${context.goalsTotalCount > 0 ? ((context.goalsCompletedCount / context.goalsTotalCount) * 100).round() : 100}%',
      };

      final renderedPrompt = _templateEngine.render(template, vars);

      final buffer = StringBuffer();
      buffer.writeln(renderedPrompt);
      buffer.writeln(context.toStructuredPrompt());
      if (customQuery != null && customQuery.trim().isNotEmpty) {
        buffer.writeln('Parent Question: $customQuery');
      }
      buffer.writeln('Local AI Assistant Response (in JSON structured format):');

      final rawResponse = await _llmProvider.generate(prompt: buffer.toString());

      final validation = _responseValidator.validateAndParse(rawResponse);
      if (validation.isValid && validation.structuredResponse != null) {
        return validation.structuredResponse!;
      }

      return _fallbackService.generateParentFallback(
        context: context,
        query: customQuery,
      );
    } catch (_) {
      return _fallbackService.generateParentFallback(
        context: context,
        query: customQuery,
      );
    }
  }

  /// Preset suggested queries for parents.
  static const List<String> suggestedParentQueries = [
    'Summarize today\'s balance',
    'How does focus time compare?',
    'What habit routines help most?',
    'Explain recent usage changes',
  ];
}
