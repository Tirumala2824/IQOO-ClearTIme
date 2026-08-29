import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/llm_models.dart';
import '../../../services/llm/local_ai_coach_service.dart';
import '../../../services/llm/local_ai_context_builder.dart';
import 'child_dashboard_controller.dart';

class ChildAiCoachState {
  final List<ChatMessage> messages;
  final bool isThinking;
  final ModelInfo? modelInfo;
  final String? errorMessage;

  const ChildAiCoachState({
    this.messages = const [],
    this.isThinking = false,
    this.modelInfo,
    this.errorMessage,
  });

  ChildAiCoachState copyWith({
    List<ChatMessage>? messages,
    bool? isThinking,
    ModelInfo? modelInfo,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChildAiCoachState(
      messages: messages ?? this.messages,
      isThinking: isThinking ?? this.isThinking,
      modelInfo: modelInfo ?? this.modelInfo,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChildAiCoachController extends StateNotifier<ChildAiCoachState> {
  final LocalAICoachService _coachService;
  final LocalAIContextBuilder _contextBuilder;
  final Ref _ref;

  ChildAiCoachController({
    required LocalAICoachService coachService,
    required LocalAIContextBuilder contextBuilder,
    required Ref ref,
  })  : _coachService = coachService,
        _contextBuilder = contextBuilder,
        _ref = ref,
        super(ChildAiCoachState(
          messages: [
            ChatMessage(
              id: 'msg-welcome',
              text:
                  "Hi Explorer! 👋 I'm your On-Device Buddy. I live right on your phone without sending any data to the cloud. Ask me anything about your focus or screen habits!",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          ],
        )) {
    _initModelInfo();
  }

  Future<void> _initModelInfo() async {
    try {
      final info = await _ref.read(localLlmProvider).getModelInfo();
      state = state.copyWith(modelInfo: info);
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
      text: text.trim(),
      isUser: true,
      timestamp: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, userMsg],
      isThinking: true,
      clearError: true,
    );

    try {
      // Build structured facts from current dashboard state
      final dashState = _ref.read(childDashboardControllerProvider);
      final aiContext = _contextBuilder.buildContext(
        usageSummary: dashState.usageSummary,
        missions: dashState.missions,
        goals: dashState.goals,
        reflection: dashState.todayReflection,
      );

      final reply = await _coachService.askCoach(
        question: text.trim(),
        context: aiContext,
      );

      final aiMsg = ChatMessage(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        text: reply,
        isUser: false,
        timestamp: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isThinking: false,
      );
    } catch (e) {
      final fallbackMsg = ChatMessage(
        id: 'err-${DateTime.now().millisecondsSinceEpoch}',
        text:
            "I'm here offline! Remember to take healthy 5-minute screen pauses and keep exploring.",
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(
        messages: [...state.messages, fallbackMsg],
        isThinking: false,
        errorMessage: e.toString(),
      );
    }
  }
}

final childAiCoachControllerProvider =
    StateNotifierProvider<ChildAiCoachController, ChildAiCoachState>((ref) {
  final coach = ref.watch(localAICoachServiceProvider);
  final builder = ref.watch(localAIContextBuilderProvider);
  return ChildAiCoachController(
    coachService: coach,
    contextBuilder: builder,
    ref: ref,
  );
});
