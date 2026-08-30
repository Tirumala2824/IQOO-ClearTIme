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

      final reply = await _coachService.askCoachAgent(
        question: text.trim(),
        context: aiContext,
        childNickname: dashState.profile?.nickname,
        missions: dashState.missions,
        goals: dashState.goals,
      );

      // Autonomous agent execution: Persist mission directly if generated
      if (reply.agentAction != null &&
          (reply.agentAction!.type == ChildAgentActionType.missionCreated ||
              reply.agentAction!.type ==
                  ChildAgentActionType.focusChallengeCreated)) {
        try {
          final missionRepo = _ref.read(localMissionRepositoryProvider);
          await missionRepo.createLocalAiMission(
            title: reply.agentAction!.title,
            description: reply.agentAction!.description,
            targetMinutes: reply.agentAction!.targetMinutes ?? 20,
            childId: dashState.profile?.id,
            childNickname: dashState.profile?.nickname,
            familyId: dashState.family?.id,
          );
          final updatedMissions =
              await missionRepo.getMissions(childId: dashState.profile?.id);
          _ref
              .read(childDashboardControllerProvider.notifier)
              .updateMissionsLocally(updatedMissions);
        } catch (_) {}
      }

      state = state.copyWith(
        messages: [...state.messages, reply],
        isThinking: false,
      );
    } catch (e) {
      state = state.copyWith(
        isThinking: false,
        errorMessage: 'Buddy is resting offline: ${e.toString()}',
      );
    }
  }

  void startNewConversation() {
    final childName =
        _ref.read(childDashboardControllerProvider).profile?.nickname;
    final welcomeName = (childName != null && childName.isNotEmpty)
        ? 'Hi $childName! 👋'
        : 'Hi there! 👋';

    state = ChildAiCoachState(
      messages: [
        ChatMessage(
          id: 'msg-welcome-${DateTime.now().millisecondsSinceEpoch}',
          text:
              "$welcomeName I'm your on-device AI Wellbeing Agent! I can create offline missions, help you focus, break down activities, or chat about your screen balance. What would you like to do?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ],
      modelInfo: state.modelInfo,
    );
  }

  Future<String?> claimDailyQuest() async {
    final dashState = _ref.read(childDashboardControllerProvider);
    final profile = dashState.profile;
    final family = dashState.family;
    if (profile == null || family == null) {
      return 'Join a family first to claim daily AI quests!';
    }

    try {
      final engine = _ref.read(autonomousAgentEngineProvider);
      final mission = await engine.claimDailyAiQuest(
        familyId: family.id,
        childId: profile.id,
        childName: profile.nickname,
      );

      final missionRepo = _ref.read(localMissionRepositoryProvider);
      final updatedMissions = await missionRepo.getMissions(childId: profile.id);
      _ref.read(childDashboardControllerProvider.notifier).updateMissionsLocally(updatedMissions);

      final buddyMsg = ChatMessage(
        id: 'msg-${DateTime.now().millisecondsSinceEpoch}',
        text: '🎉 Awesome! I created your daily activity: "${mission.title}" (${mission.targetMinutes}m). Check it out in your Activities tab!',
        isUser: false,
        timestamp: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, buddyMsg]);

      return 'Created activity: ${mission.title} (${mission.targetMinutes}m)';
    } catch (e) {
      return 'Could not create activity right now: $e';
    }
  }

  void clearConversationHistory() {
    state = ChildAiCoachState(
      messages: [],
      modelInfo: state.modelInfo,
    );
  }
}

final childAiCoachControllerProvider =
    StateNotifierProvider<ChildAiCoachController, ChildAiCoachState>((ref) {
  final coach = ref.watch(localAICoachServiceProvider);
  final builder = ref.watch(localAIContextBuilderProvider);
  final childName =
      ref.read(childDashboardControllerProvider).profile?.nickname;
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
