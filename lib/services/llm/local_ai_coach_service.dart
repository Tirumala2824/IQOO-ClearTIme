import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';
import '../../data/repositories/local_prompt_repository.dart';
import '../../data/repositories/local_ai_settings_repository.dart';
import 'local_ai_context_builder.dart';
import 'prompt_template_engine.dart';
import 'ai_response_validator.dart';
import 'deterministic_fallback_service.dart';

/// LocalAICoachService provides child-facing wellbeing guidance.
///
/// SAFETY INVARIANT:
/// 1. Analytical facts are dynamically bound through the safe PromptTemplateEngine.
/// 2. If AI is disabled or local LLM is unavailable, DeterministicFallbackService provides 100% offline fact summaries.
/// 3. All outputs are validated through AIResponseValidator.
class LocalAICoachService {
  final LocalLLMProvider _llmProvider;
  final LocalAIContextBuilder _contextBuilder;
  final LocalPromptRepository _promptRepo;
  final LocalAISettingsRepository _settingsRepo;
  final PromptTemplateEngine _templateEngine;
  final AIResponseValidator _responseValidator;
  final DeterministicFallbackService _fallbackService;

  const LocalAICoachService({
    required LocalLLMProvider llmProvider,
    LocalAIContextBuilder contextBuilder = const LocalAIContextBuilder(),
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

  LocalAIContextBuilder get contextBuilder => _contextBuilder;

  /// Asks the on-device AI coach a question within the child's wellbeing context.
  Future<StructuredAIResponse> askCoach({
    required String question,
    required AIContext context,
  }) async {
    final settings = await _settingsRepo.getSettings();
    if (!settings.isAiEnabled) {
      return _fallbackService.generateDisabledMessage();
    }

    final isReady = await _llmProvider.isAvailable();
    if (!isReady) {
      return _fallbackService.generateChildFallback(
        context: context,
        question: question,
      );
    }

    try {
      final promptDef =
          await _promptRepo.getActivePromptByType(PromptType.childInsight);
      final template = promptDef?.content ??
          'You are ClearTime Buddy, an encouraging coach for {{child_name}}. Today {{child_name}} used {{screen_time}} with {{focus_time}} focus. Celebrate mindful progress!';

      final hours = context.todayUsageMinutes ~/ 60;
      final mins = context.todayUsageMinutes % 60;
      final screenTimeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      final focusHours = context.focusMinutes ~/ 60;
      final focusMins = context.focusMinutes % 60;
      final focusTimeStr =
          focusHours > 0 ? '${focusHours}h ${focusMins}m' : '${focusMins}m';

      final prevMins = context.usageChangePercentage != 0
          ? (context.todayUsageMinutes / (1.0 + (context.usageChangePercentage / 100.0))).round().clamp(0, 1440)
          : context.todayUsageMinutes;
      final prevHours = prevMins ~/ 60;
      final prevRemainMins = prevMins % 60;
      final prevTimeStr = prevMins > 0 ? (prevHours > 0 ? '${prevHours}h ${prevRemainMins}m' : '${prevRemainMins}m') : '0m';

      final totalGoalsAndMissions = context.activeGoalsCount + context.completedMissions;
      final progressPct = totalGoalsAndMissions > 0
          ? ((context.completedMissions / totalGoalsAndMissions) * 100).round()
          : 0;

      final vars = {
        'child_name': 'Explorer',
        'screen_time': screenTimeStr,
        'previous_screen_time': prevTimeStr,
        'usage_change':
            '${context.usageChangePercentage >= 0 ? "+" : ""}${context.usageChangePercentage.toStringAsFixed(1)}%',
        'focus_time': focusTimeStr,
        'top_category': context.topCategory,
        'goal_progress': '$progressPct%',
        'achievement': context.completedMissions > 0 ? 'Active Explorer' : 'Getting Started',
        'break_count': '${context.breakCount}',
        'completed_missions': '${context.completedMissions}',
      };

      final renderedPrompt = _templateEngine.render(template, vars);

      final promptBuffer = StringBuffer();
      promptBuffer.writeln(renderedPrompt);
      promptBuffer.writeln(context.toStructuredPrompt());
      promptBuffer.writeln('Child Question: $question');
      promptBuffer.writeln('Buddy Response (JSON or encouraging guidance):');

      final rawResponse =
          await _llmProvider.generate(prompt: promptBuffer.toString());

      final validation = _responseValidator.validateAndParse(rawResponse);
      if (validation.isValid && validation.structuredResponse != null) {
        return validation.structuredResponse!;
      }

      // Retry locally or fallback
      return _fallbackService.generateChildFallback(
        context: context,
        question: question,
      );
    } catch (_) {
      return _fallbackService.generateChildFallback(
        context: context,
        question: question,
      );
    }
  }

  /// Suggested prompt queries for the child.
  static const List<String> suggestedPrompts = [
    'How did I do today?',
    'Help me focus.',
    'Give me a challenge.',
    'What changed today?',
    'How can I reduce distractions?',
  ];
}
