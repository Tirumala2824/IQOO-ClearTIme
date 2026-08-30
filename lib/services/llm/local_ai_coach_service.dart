import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/goal_model.dart';
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
    String? childNickname,
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
        'child_name': (childNickname == null || childNickname.trim().isEmpty)
            ? 'your child'
            : childNickname.trim(),
        'screen_time': screenTimeStr,
        'previous_screen_time': prevTimeStr,
        'usage_change':
            '${context.usageChangePercentage >= 0 ? "+" : ""}${context.usageChangePercentage.toStringAsFixed(1)}%',
        'focus_time': focusTimeStr,
        'top_category': context.topCategory,
        'goal_progress': '$progressPct%',
        'achievement': context.completedMissions > 0 ? 'Progress made' : 'Getting started',
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

  /// Asks the on-device AI coach as an interactive AI Agent with autonomous actions.
  Future<ChatMessage> askCoachAgent({
    required String question,
    required AIContext context,
    String? childNickname,
    List<ChildMission> missions = const [],
    List<ChildGoal> goals = const [],
  }) async {
    final now = DateTime.now();
    final name = (childNickname != null && childNickname.trim().isNotEmpty)
        ? childNickname.trim()
        : 'Buddy';

    final qLower = question.toLowerCase();

    // 1. Mission Creation Agent Action
    if (qLower.contains('challenge') ||
        qLower.contains('new mission') ||
        qLower.contains('give me a mission') ||
        qLower.contains('suggest an activity') ||
        qLower.contains('offline activity')) {
      final ideas = [
        {
          'title': 'Origami & Drawing Quest',
          'desc': 'Fold 2 origami animals or sketch your favorite character.',
          'duration': 20,
        },
        {
          'title': 'Outdoor Fresh-Air Sprint',
          'desc': 'Step outside, stretch, or jog around the yard for 20 minutes.',
          'duration': 20,
        },
        {
          'title': 'LEGO Castle Architect',
          'desc': 'Construct a castle, tower, or car with blocks without any screens.',
          'duration': 30,
        },
        {
          'title': 'Book Reading Exploration',
          'desc': 'Read 15 pages of your current favorite story or graphic novel.',
          'duration': 25,
        },
        {
          'title': 'Mindful Eye Rest & Puzzle',
          'desc': 'Solve a physical jigsaw puzzle or play a board game with family.',
          'duration': 20,
        },
      ];
      final chosen = (ideas..shuffle()).first;

      return ChatMessage(
        id: 'agent-${now.millisecondsSinceEpoch}',
        text: 'Awesome $name! 🌟 I generated a fun offline mission for you: **${chosen['title']}** (${chosen['duration']} mins). Ready to take on the challenge?',
        isUser: false,
        timestamp: now,
        agentAction: ChildAgentAction(
          type: ChildAgentActionType.missionCreated,
          title: chosen['title'] as String,
          description: chosen['desc'] as String,
          targetMinutes: chosen['duration'] as int,
        ),
      );
    }

    // 2. Focus Challenge Action
    if (qLower.contains('help me focus') ||
        qLower.contains('focus challenge') ||
        qLower.contains('focus timer')) {
      return ChatMessage(
        id: 'agent-${now.millisecondsSinceEpoch}',
        text: 'Let\'s get in the zone, $name! 🎯 I\'ve activated a 15-minute Deep Focus Sprint. Put away background noise and let\'s conquer this goal!',
        isUser: false,
        timestamp: now,
        agentAction: const ChildAgentAction(
          type: ChildAgentActionType.focusChallengeCreated,
          title: '15-Minute Focus Sprint',
          description: 'Focus on one learning or creative task with zero distraction.',
          targetMinutes: 15,
        ),
      );
    }

    // 3. Task Breakdown Action
    if (qLower.contains('break down') ||
        qLower.contains('too hard') ||
        qLower.contains('help with task')) {
      final activeMission = missions.isNotEmpty
          ? missions.first.title
          : 'Your daily offline mission';
      return ChatMessage(
        id: 'agent-${now.millisecondsSinceEpoch}',
        text: 'Here is how you can easily complete "$activeMission" step by step! 💪',
        isUser: false,
        timestamp: now,
        agentAction: ChildAgentAction(
          type: ChildAgentActionType.taskBreakdown,
          title: 'Step-by-Step Game Plan',
          steps: [
            '1. Clear your workspace and grab any needed materials.',
            '2. Spend the first 10 minutes getting started without rush.',
            '3. Take a quick stretch break, then wrap up the remaining part!',
          ],
        ),
      );
    }

    // 4. Conversational guidance using on-device LLM
    final structured = await askCoach(
      question: question,
      context: context,
      childNickname: childNickname,
    );

    return ChatMessage(
      id: 'agent-${now.millisecondsSinceEpoch}',
      text: structured.answer,
      isUser: false,
      timestamp: now,
      structuredResponse: structured,
    );
  }

  /// Suggested prompt queries for the child.
  static const List<String> suggestedPrompts = [
    '✨ Give me a mission challenge',
    '🎯 Help me focus for 15 mins',
    '💡 Break down my activity',
    '📊 How did I do today?',
    '🧘 Suggest a quick screen break',
  ];
}
