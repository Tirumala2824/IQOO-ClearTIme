import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/llm_models.dart';
import 'local_ai_context_builder.dart';

/// LocalAICoachService provides child-facing wellbeing guidance.
///
/// SAFETY INVARIANT:
/// Analytical facts are embedded into the prompt, and the coach
/// explains them with encouraging, positive reinforcement.
class LocalAICoachService {
  final LocalLLMProvider _llmProvider;
  final LocalAIContextBuilder _contextBuilder;

  const LocalAICoachService({
    required LocalLLMProvider llmProvider,
    LocalAIContextBuilder contextBuilder = const LocalAIContextBuilder(),
  })  : _llmProvider = llmProvider,
        _contextBuilder = contextBuilder;

  LocalAIContextBuilder get contextBuilder => _contextBuilder;

  /// Asks the on-device AI coach a question within the child's wellbeing context.
  Future<String> askCoach({
    required String question,
    required AIContext context,
  }) async {
    final isReady = await _llmProvider.isAvailable();
    if (!isReady) {
      return "Your On-Device Buddy is resting right now. Keep enjoying your mindful quests!";
    }

    final promptBuffer = StringBuffer();
    promptBuffer.writeln('You are ClearTime Buddy, a kind, encouraging on-device wellbeing coach for a young explorer.');
    promptBuffer.writeln('Explain the following real facts clearly and cheerfully. Do NOT invent new numbers or change metrics.');
    promptBuffer.writeln(context.toStructuredPrompt());
    promptBuffer.writeln('Child Question: $question');
    promptBuffer.writeln('Buddy Response:');

    final response = await _llmProvider.generate(prompt: promptBuffer.toString());

    if (response.isEmpty) {
      return "You're making wonderful progress today! Remember to take healthy breaks and celebrate every mindful quest.";
    }

    return response;
  }

  /// Preset prompt options for the child.
  static const List<String> suggestedPrompts = [
    'How did I do today?',
    'Help me focus.',
    'Give me a challenge.',
    'What changed today?',
    'How can I reduce distractions?',
  ];
}
