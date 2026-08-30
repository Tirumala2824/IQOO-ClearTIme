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
    String welcomeName = 'Hi there! 👋',
  })  : _coachService = coachService,
        _contextBuilder = contextBuilder,
        _ref = ref,
        super(ChildAiCoachState(
          messages: [
            ChatMessage(
              id: 'msg-welcome',
              text:
                  "$welcomeName I'm your on-device wellbeing buddy. I think "
                  'right on your phone — no data is sent to the cloud. Ask me '
                  'about your focus or screen habits!',
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
        childNickname: dashState.profile?.nickname,
      );

      final aiMsg = ChatMessage(
        id: 'reply-${DateTime.now().millisecondsSinceEpoch}',
        text: reply.answer,
        isUser: false,
        timestamp: DateTime.now(),
        structuredResponse: reply,
      );

      state = state.copyWith(
        messages: [...state.messages, aiMsg],
        isThinking: false,
      );
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        errorMessage: 'Buddy is resting offline: ${e.toString()}',
      );
    }
  }
}

final childAiCoachControllerProvider =
    StateNotifierProvider<ChildAiCoachController, ChildAiCoachState>((ref) {
  final coach = ref.watch(localAICoachServiceProvider);
  final builder = ref.watch(localAIContextBuilderProvider);
  final childName = ref.read(childDashboardControllerProvider).profile?.nickname;
    final welcomeName = (childName != null && childName.isNotEmpty)
        ? 'Hi $childName! 👋'
        : 'Hi there! 👋';

    return ChildAiCoachController(
      coachService: coach,
      contextBuilder: builder,
      ref: ref,
      welcomeName: welcomeName,
    );
});
