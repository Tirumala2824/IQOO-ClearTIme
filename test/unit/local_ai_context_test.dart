import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/services/abstractions/local_llm_provider.dart';
import 'package:cleartime/data/models/llm_models.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/goal_model.dart';
import 'package:cleartime/data/models/reflection_model.dart';
import 'package:cleartime/data/repositories/local_prompt_repository.dart';
import 'package:cleartime/data/repositories/local_ai_settings_repository.dart';
import 'package:cleartime/services/llm/local_ai_context_builder.dart';
import 'package:cleartime/services/llm/local_ai_coach_service.dart';

import '../helpers/encrypted_store_helper.dart';

/// In-memory offline LLM returning an encouraging structured answer, so the
/// coach service pipeline runs without any native runtime or network access.
class _FakeOfflineLLMProvider implements LocalLLMProvider {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> loadModel() async {}

  @override
  Future<void> loadModelById(String modelId) async {}

  @override
  Future<void> unloadModel() async {}

  @override
  Future<String> generate({required String prompt}) async =>
      '{"answer":"You did wonderfully today! Keep up the great mindful focus.",'
      '"observations":["Positive reinforcement delivered"],'
      '"evidence":["Local device facts"],'
      '"recommendations":["Keep making mindful choices"],"confidence":0.95}';

  @override
  Future<ModelInfo> getModelInfo() async => const ModelInfo(
        modelName: 'ClearTime-SLM-Nano',
        version: '1.0.0',
        contextLimit: 2048,
        quantization: 'q4_k_m',
        sizeMb: 450,
        isLoaded: true,
      );

  @override
  Future<int> getContextLimit() async => 2048;

  @override
  Future<int> getMemoryUsage() async => 280;

  @override
  Future<List<LocalModelCatalogEntry>> getInstalledModels() async => [];

  @override
  Future<List<LocalModelCatalogEntry>> getAvailableModels() async => [];

  @override
  Future<bool> installModel(String modelId) async => true;

  @override
  Future<bool> deleteModel(String modelId) async => true;

  @override
  Future<bool> selectModel(String modelId) async => true;

  @override
  Future<StructuredAIResponse> testInference({
    String? modelId,
    String? testPrompt,
  }) async =>
      const StructuredAIResponse(answer: 'Local test OK', confidence: 1.0);
}

void main() {
  group('Local AI Context Builder and Child Coach Unit Tests', () {
    const builder = LocalAIContextBuilder();

    test('LocalAIContextBuilder creates structured facts without raw timeline data', () {
      const summary = UsageSummary(
        totalMinutes: 140,
        focusMinutes: 80,
        breakCount: 4,
        changePercentageFromYesterday: -15.5,
        categories: [
          CategoryUsage(category: 'Education', totalMinutes: 80, percentage: 57.1),
          CategoryUsage(category: 'Games', totalMinutes: 60, percentage: 42.9),
        ],
      );

      final missions = [
        ChildMission(
          id: 'm-1',
          title: 'Math Quest',
          description: 'Study 20 min',
          type: MissionType.focus,
          targetMinutes: 20,
          status: MissionStatus.approved,
        ),
      ];

      final goals = [
        ChildGoal(
          id: 'g-1',
          title: 'Daily Focus',
          description: 'Focus 60m',
          type: GoalType.dailyFocus,
          targetMinutes: 60,
          status: GoalStatus.active,
          createdAt: DateTime.now(),
        ),
      ];

      final reflection = DailyReflection(
        id: 'r-1',
        date: DateTime.now(),
        mood: ReflectionMood.productive,
        notes: 'Great study session',
        createdAt: DateTime.now(),
      );

      final context = builder.buildContext(
        usageSummary: summary,
        missions: missions,
        goals: goals,
        reflection: reflection,
      );

      expect(context.todayUsageMinutes, equals(140));
      expect(context.focusMinutes, equals(80));
      expect(context.breakCount, equals(4));
      expect(context.topCategory, equals('Education'));
      expect(context.completedMissions, equals(1));
      expect(context.recentReflection, contains('Productive'));

      final promptText = context.toStructuredPrompt();
      expect(promptText, contains('Total Screen Time: 140 minutes'));
      expect(promptText, contains('Focused Learning/Reading Time: 80 minutes'));
      expect(promptText, contains('Mindful Breaks Taken: 4 breaks'));
      expect(promptText, contains('DO NOT MODIFY METRICS'));
    });

    test('LocalAICoachService answers child prompts with positive reinforcement', () async {
      final store = await createTestDeviceStore();
      final llmProvider = _FakeOfflineLLMProvider();
      final promptRepo = EncryptedLocalPromptRepository(store: store);
      final settingsRepo = EncryptedLocalAISettingsRepository(store: store);

      final coach = LocalAICoachService(
        llmProvider: llmProvider,
        contextBuilder: builder,
        promptRepo: promptRepo,
        settingsRepo: settingsRepo,
      );

      final context = builder.buildContext(
        usageSummary: const UsageSummary(
          totalMinutes: 120,
          focusMinutes: 70,
          breakCount: 4,
        ),
        missions: const [],
        goals: const [],
      );

      final reply = await coach.askCoach(
        question: 'How did I do today?',
        context: context,
      );

      expect(reply.answer, isNotEmpty);
      expect(reply.answer.toLowerCase(),
          anyOf(contains('wonderfully'), contains('great'), contains('focus'), contains('progress')));
    });
  });
}
