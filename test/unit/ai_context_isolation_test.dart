import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/reflection_model.dart';
import 'package:cleartime/services/llm/local_ai_context_builder.dart';
import 'package:cleartime/services/llm/parent_ai_context_builder.dart';
import 'package:cleartime/services/llm/parent_ai_service.dart';
import 'package:cleartime/services/llm/local_ai_coach_service.dart';
import 'package:cleartime/services/llm/on_device_llm_provider.dart';
import 'package:cleartime/data/repositories/local_prompt_repository.dart';
import 'package:cleartime/data/repositories/local_ai_settings_repository.dart';

void main() {
  group('AI Context Isolation & Strict Privacy Tests', () {
    const childBuilder = LocalAIContextBuilder();
    const parentBuilder = ParentAIContextBuilder();

    const testUsage = UsageSummary(
      totalMinutes: 150,
      focusMinutes: 60,
      breakCount: 4,
      changePercentageFromYesterday: -8.0,
      categories: [
        CategoryUsage(category: 'Learning', totalMinutes: 60, percentage: 40.0),
        CategoryUsage(category: 'Games', totalMinutes: 90, percentage: 60.0),
      ],
    );

    final privateChildReflection = DailyReflection(
      id: 'ref-secret',
      date: DateTime.now(),
      mood: ReflectionMood.distracting,
      notes: 'Secret personal thoughts: I felt anxious about math test today.',
      createdAt: DateTime.now(),
    );

    test('Child AI Context contains child reflection for empathetic coaching', () {
      final childContext = childBuilder.buildContext(
        usageSummary: testUsage,
        missions: const [],
        goals: const [],
        reflection: privateChildReflection,
      );

      final prompt = childContext.toStructuredPrompt();
      expect(prompt, contains('Child Daily Reflection'));
      expect(prompt, contains('Distracting'));
      expect(prompt, contains('Secret personal thoughts'));
    });

    test('Parent AI Context strictly OMITS private child reflections and raw logs', () {
      final parentContext = parentBuilder.buildContext(
        childNickname: 'Sam',
        usageSummary: testUsage,
        goalsCompleted: 3,
        goalsTotal: 4,
        activeAlerts: const ['Night Limit Warning'],
        reportDateFormatted: 'Today',
      );

      final prompt = parentContext.toStructuredPrompt();

      // INVARIANT: Parent context contains only approved aggregates
      expect(prompt, contains('APPROVED PARENT REPORT FACTS'));
      expect(prompt, contains('Total Screen Time: 150 min'));
      expect(prompt, contains('Focus Time: 60 min'));
      expect(prompt, contains('Goals Progress: 3 of 4 achieved'));
      expect(prompt, contains('Night Limit Warning'));

      // STRICT PRIVACY CHECK: Private reflection MUST NEVER be in parent prompt
      expect(prompt.contains('Secret personal thoughts'), isFalse);
      expect(prompt.contains('anxious about math'), isFalse);
      expect(prompt.contains('ref-secret'), isFalse);
    });

    test('ParentAIService executes offline with isolated context without network calls', () async {
      final llm = OnDeviceLLMProvider();
      final promptRepo = InMemoryLocalPromptRepository();
      final settingsRepo = InMemoryLocalAISettingsRepository();

      final parentService = ParentAIService(
        llmProvider: llm,
        contextBuilder: parentBuilder,
        promptRepo: promptRepo,
        settingsRepo: settingsRepo,
      );

      final parentContext = parentBuilder.buildContext(
        childNickname: 'Sam',
        usageSummary: testUsage,
      );

      final response = await parentService.analyzeReport(context: parentContext);

      expect(response.answer, isNotEmpty);
      expect(response.isFallback, isFalse);
      expect(response.confidence, greaterThanOrEqualTo(0.9));
      expect(response.observations, isNotEmpty);
    });

    test('Local AI disabled state produces safe deterministic fallback for both child and parent', () async {
      final llm = OnDeviceLLMProvider();
      final promptRepo = InMemoryLocalPromptRepository();
      final settingsRepo = InMemoryLocalAISettingsRepository();

      // Disable AI
      await settingsRepo.setAiEnabled(false);

      final childCoach = LocalAICoachService(
        llmProvider: llm,
        contextBuilder: childBuilder,
        promptRepo: promptRepo,
        settingsRepo: settingsRepo,
      );

      final parentService = ParentAIService(
        llmProvider: llm,
        contextBuilder: parentBuilder,
        promptRepo: promptRepo,
        settingsRepo: settingsRepo,
      );

      final childContext = childBuilder.buildContext(
        usageSummary: testUsage,
        missions: const [],
        goals: const [],
      );

      final parentContext = parentBuilder.buildContext(
        childNickname: 'Sam',
        usageSummary: testUsage,
      );

      final childReply = await childCoach.askCoach(
        question: 'How am I doing?',
        context: childContext,
      );

      final parentReply = await parentService.analyzeReport(
        context: parentContext,
      );

      expect(childReply.isFallback, isTrue);
      expect(childReply.answer, contains('disabled in Settings'));

      expect(parentReply.isFallback, isTrue);
      expect(parentReply.answer, contains('disabled in Settings'));
    });
  });
}
