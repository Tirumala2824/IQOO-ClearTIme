import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/services/abstractions/usage_data_provider.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/repositories/local_mission_repository.dart';
import 'package:cleartime/services/llm/local_ai_activity_service.dart';
import 'package:cleartime/services/llm/local_model_runtime.dart';

class _FakeUsage implements UsageDataProvider {
  _FakeUsage({this.state = UsageAccessState.ready, this.total = 90});

  final UsageAccessState state;
  final int total;

  @override
  Future<UsageAccessState> getUsageAccessState() async => state;

  @override
  Future<bool> hasUsagePermission() async => state == UsageAccessState.ready;

  @override
  Future<bool> requestUsagePermission() async => true;

  @override
  Future<UsageSummary> getTodayUsage() async => UsageSummary(
        totalMinutes: total,
        focusMinutes: 40,
        breakCount: 2,
        screenUnlockCount: 8,
        categories: const [],
        topApps: const [],
      );

  @override
  Future<List<DailyUsage>> getDailyUsage() async => const [];
  @override
  Future<List<DailyUsage>> getWeeklyUsage() async => const [];
  @override
  Future<List<DailyUsage>> getMonthlyUsage() async => const [];
  @override
  Future<List<CategoryUsage>> getCategoryUsage() async => const [];
  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async => const [];
  @override
  Future<List<FocusSession>> getFocusSessions() async => const [];
}

class _ReadyRuntime implements LocalModelRuntime {
  _ReadyRuntime({this.ready = true});

  final bool ready;

  @override
  String get engineName => 'test';

  @override
  ModelRuntimeStatus get status =>
      ready ? ModelRuntimeStatus.ready : ModelRuntimeStatus.error;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> loadModel(VerifiedModelArtifact artifact) async {}

  @override
  Future<void> unload() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<ModelGenerationResult> generate(String prompt,
      {int maxTokens = 512}) async {
    return const ModelGenerationResult(
      text:
          '{"answer":"Take a 20 minute walk outside.","observations":["Walk outside"],"recommendations":["Enjoy the fresh air"],"confidence":0.9}',
      tokensGenerated: 12,
      elapsed: Duration(milliseconds: 10),
    );
  }
}

void main() {
  group('LocalAiActivityService', () {
    test('creates an activity only when usage access is ready', () async {
      final service = LocalAiActivityService(
        usageProvider: _FakeUsage(state: UsageAccessState.permissionNeeded),
        missionRepository: InMemoryLocalMissionRepository(),
        runtime: _ReadyRuntime(),
      );
      final result = await service.tryGenerate();
      expect(result.isCreated, isFalse);
      expect(result.explanation, contains('usage access'));
    });

    test('skips when no usage is recorded today', () async {
      final service = LocalAiActivityService(
        usageProvider: _FakeUsage(total: 0),
        missionRepository: InMemoryLocalMissionRepository(),
        runtime: _ReadyRuntime(),
      );
      final result = await service.tryGenerate();
      expect(result.isCreated, isFalse);
      expect(result.explanation, contains('no recorded usage'));
    });

    test('creates a direct auto-assignment from a validated response',
        () async {
      final repo = InMemoryLocalMissionRepository();
      final service = LocalAiActivityService(
        usageProvider: _FakeUsage(),
        missionRepository: repo,
        runtime: _ReadyRuntime(),
      );
      final result = await service.tryGenerate();
      expect(result.isCreated, isTrue);
      expect(result.mission!.source, MissionSource.localAi);
      expect(result.mission!.proofRequirement, ProofRequirement.noProof);
      expect(result.mission!.reward, isNull);
      expect(result.mission!.status, MissionStatus.assigned);
    });

    test('enforces one open AI activity per day', () async {
      final repo = InMemoryLocalMissionRepository();
      final service = LocalAiActivityService(
        usageProvider: _FakeUsage(),
        missionRepository: repo,
        runtime: _ReadyRuntime(),
      );
      await service.tryGenerate();
      final second = await service.tryGenerate();
      expect(second.isCreated, isFalse);
      expect(second.explanation, contains('already have an AI activity'));
    });

    test('fails truthfully when the model is not ready', () async {
      final service = LocalAiActivityService(
        usageProvider: _FakeUsage(),
        missionRepository: InMemoryLocalMissionRepository(),
        runtime: _ReadyRuntime(ready: false),
      );
      final result = await service.tryGenerate();
      expect(result.isCreated, isFalse);
      expect(result.explanation, contains('local model is not ready'));
    });

    test('rejects an invalid structured model response', () async {
      final service = LocalAiActivityService(
        usageProvider: _FakeUsage(),
        missionRepository: InMemoryLocalMissionRepository(),
        runtime: _InvalidResponseRuntime(),
      );
      final result = await service.tryGenerate();
      expect(result.isCreated, isFalse);
      expect(result.explanation, contains('not valid'));
    });
  });
}

class _InvalidResponseRuntime extends _ReadyRuntime {
  @override
  Future<ModelGenerationResult> generate(String prompt,
      {int maxTokens = 512}) async {
    return const ModelGenerationResult(
      text: '   ',
      tokensGenerated: 0,
      elapsed: Duration(milliseconds: 1),
    );
  }
}
