import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/services/abstractions/local_llm_provider.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/llm_models.dart';
import 'package:cleartime/data/repositories/local_ai_settings_repository.dart';
import 'package:cleartime/data/repositories/local_prompt_repository.dart';
import 'package:cleartime/data/repositories/parent_conversation_repository.dart';
import 'package:cleartime/services/llm/parent_ai_service.dart';
import 'package:cleartime/services/storage/encrypted_device_store.dart';

import '../helpers/encrypted_store_helper.dart';

/// In-memory offline LLM returning a valid structured answer so the parent
/// AI service runs its real validation pipeline without any native runtime.
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
      '{"answer":"Focus time improved by about 30 minutes this week.",'
      '"observations":["Focus engagement increased"],'
      '"evidence":["Approved report facts"],'
      '"recommendations":["Keep the weekend routine consistent"],'
      '"confidence":0.95}';

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
  group('Parent AI Chat & Conversation Unit Tests', () {
    late ParentAIService aiService;
    late ParentConversationRepository convoRepo;
    late LocalAISettingsRepository settingsRepo;
    late LocalPromptRepository promptRepo;

    final now = DateTime(2026, 8, 29);
    final sampleReport = ApprovedReport(
      id: 'rep-alex-weekly',
      childId: 'child-1',
      childNickname: 'Alex',
      familyId: 'family-1',
      period: ReportPeriod.weekly,
      periodStart: now.subtract(const Duration(days: 7)),
      periodEnd: now,
      facts: const ReportFacts(
        totalScreenMinutes: 872,
        previousScreenMinutes: 778,
        changePercentage: 12.1,
        focusMinutes: 370,
        breakCount: 22,
        goalsCompletedCount: 5,
        goalsTotalCount: 7,
      ),
      summaryText:
          'Alex spent 14h 32m on connected devices this week with 6h 10m focus time.',
      createdAt: now,
    );

    setUp(() async {
      final store = await createTestDeviceStore();
      // Hive boxes are process-global across tests in this file, so reset the
      // boxes this suite touches for deterministic per-test state.
      await store.clearBox(EncryptedDeviceStore.aiSettingsBox);
      await store.clearBox(EncryptedDeviceStore.parentConversationsBox);
      settingsRepo = EncryptedLocalAISettingsRepository(store: store);
      promptRepo = EncryptedLocalPromptRepository(store: store);
      convoRepo = EncryptedParentConversationRepository(store: store);
      aiService = ParentAIService(
        llmProvider: _FakeOfflineLLMProvider(),
        promptRepo: promptRepo,
        settingsRepo: settingsRepo,
      );
    });

    test('Missing information requests are safely intercepted without device access', () async {
      const forbiddenQuery = 'What exact app was used at 11:42 PM?';
      expect(aiService.isQueryForUnavailableInfo(forbiddenQuery), isTrue);

      final reply = await aiService.askAboutApprovedReport(
        report: sampleReport,
        query: forbiddenQuery,
      );

      expect(reply.isMissingDataNotice, isTrue);
      expect(reply.text, contains('That information isn\'t available in the approved wellbeing report'));
    });

    test('Parent AI provides factual report answers with evidence', () async {
      final reply = await aiService.askAboutApprovedReport(
        report: sampleReport,
        query: 'How does focus time compare this week?',
      );

      expect(reply.isUser, isFalse);
      expect(reply.text.isNotEmpty, isTrue);
      expect(reply.evidence.any((e) => e.metric == 'Screen Time'), isTrue);
    });

    test('ParentConversationRepository creates, updates, and deletes multi-turn chats', () async {
      final convo = ParentAIConversation(
        id: 'test-convo-1',
        childId: 'child-1',
        title: 'Habit Discussion',
        messages: [
          ParentChatMessage(
            id: 'm1',
            text: 'Why did usage change this week?',
            isUser: true,
            timestamp: now,
          ),
          ParentChatMessage(
            id: 'm2',
            text: 'Usage increased by 12.1% due to weekend learning tasks.',
            isUser: false,
            timestamp: now,
            evidence: const [
              AIEvidence(
                metric: 'Screen Time',
                currentValue: '14h 32m',
                previousValue: '12h 58m',
                change: '+12.1%',
              ),
            ],
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      await convoRepo.saveConversation(convo);
      var list = await convoRepo.getConversations('child-1');
      expect(list.any((c) => c.id == 'test-convo-1'), isTrue);

      await convoRepo.deleteConversation('test-convo-1');
      list = await convoRepo.getConversations('child-1');
      expect(list.any((c) => c.id == 'test-convo-1'), isFalse);
    });

    test('AI disabled setting falls back gracefully to deterministic facts', () async {
      await settingsRepo.updateSettings(const AISettings(isAiEnabled: false));

      final reply = await aiService.askAboutApprovedReport(
        report: sampleReport,
        query: 'Give me a summary',
      );

      expect(reply.text, contains('Alex spent 14h 32m'));
      expect(reply.isUser, isFalse);
    });
  });
}