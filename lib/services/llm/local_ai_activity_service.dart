import '../../core/services/abstractions/usage_data_provider.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/usage_models.dart';
import '../../data/repositories/local_mission_repository.dart';
import 'ai_response_validator.dart';
import 'local_model_runtime.dart';

/// Result of an AI activity generation attempt.
class AiActivityResult {
  final ChildMission? mission;
  final String? explanation;

  const AiActivityResult.created(this.mission) : explanation = null;

  const AiActivityResult.skipped(this.explanation)
      : mission = null;

  bool get isCreated => mission != null;
}

/// Generates AI-created activities strictly from a valid, current local
/// usage summary and a validated structured model response.
///
/// Requirements enforced here:
///  * [UsageAccessState.ready] — otherwise nothing is created and a truthful
///    explanation is returned;
///  * a validated structured response — a failed/missing model produces no
///    activity;
///  * one new AI activity per child per day unless the previous one is
///    finished/expired (client-side pre-check; the database RPC enforces the
///    same rule transactionally);
///  * created activities are direct auto-assignments: source=local_ai, no
///    default reward, no proof requirement.
class LocalAiActivityService {
  final UsageDataProvider _usageProvider;
  final LocalMissionRepository _missionRepository;
  final LocalModelRuntime _runtime;
  final AIResponseValidator _validator;

  LocalAiActivityService({
    required UsageDataProvider usageProvider,
    required LocalMissionRepository missionRepository,
    required LocalModelRuntime runtime,
    AIResponseValidator validator = const AIResponseValidator(),
  })  : _usageProvider = usageProvider,
        _missionRepository = missionRepository,
        _runtime = runtime,
        _validator = validator;

  Future<bool> get _hasOpenAiActivityToday async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final missions = await _missionRepository.getMissions();
    return missions.any((m) =>
        m.source == MissionSource.localAi &&
        m.status != MissionStatus.approved &&
        m.status != MissionStatus.expired &&
        m.createdAt.year == today.year &&
        m.createdAt.month == today.month &&
        m.createdAt.day == today.day);
  }

  /// Attempts to create one AI activity for the current usage day.
  Future<AiActivityResult> tryGenerate() async {
    final accessState = await _usageProvider.getUsageAccessState();
    if (accessState != UsageAccessState.ready) {
      return AiActivityResult.skipped(
        'No AI activity was created: usage access is not available '
        '(${accessState.name}). Enable Usage Access in setup first.',
      );
    }

    final UsageSummary usage;
    try {
      usage = await _usageProvider.getTodayUsage();
    } catch (_) {
      return const AiActivityResult.skipped(
        'No AI activity was created: today\'s usage could not be read.',
      );
    }

    if (usage.totalMinutes <= 0) {
      return const AiActivityResult.skipped(
        'No AI activity was created: there is no recorded usage for today yet.',
      );
    }

    if (await _hasOpenAiActivityToday) {
      return const AiActivityResult.skipped(
        'You already have an AI activity for today. Finish or let it expire '
        'before a new one is created.',
      );
    }

    if (_runtime.status != ModelRuntimeStatus.ready) {
      return const AiActivityResult.skipped(
        'No AI activity was created: the local model is not ready. '
        'Complete AI setup on this device first.',
      );
    }

    // Minimized, on-device context only: date range, aggregate durations,
    // categories, breaks. No raw packages, events, reflections, or chats.
    final prompt = _buildPrompt(usage);
    final ModelGenerationResult response;
    try {
      response = await _runtime.generate(prompt);
    } catch (_) {
      return const AiActivityResult.skipped(
        'No AI activity was created: the local model failed to respond.',
      );
    }

    final parsed = _validator.validateAndParse(response.text);
    if (!parsed.isValid || parsed.structuredResponse == null) {
      return const AiActivityResult.skipped(
        'No AI activity was created: the model response was not valid.',
      );
    }

    final answer = parsed.structuredResponse!.answer.trim();
    final title = _titleFrom(answer);
    final description = parsed.structuredResponse!.observations.isNotEmpty
        ? parsed.structuredResponse!.observations.join(' ')
        : answer;

    try {
      final mission = await _missionRepository.createLocalAiMission(
        title: title,
        description: description,
        targetMinutes: _suggestedMinutes(usage),
      );
      return AiActivityResult.created(mission);
    } catch (e) {
      return AiActivityResult.skipped(
        'The AI activity could not be saved: $e',
      );
    }
  }

  String _buildPrompt(UsageSummary usage) {
    final categoryText = usage.categories
        .map((c) => '${c.category}: ${c.totalMinutes} min')
        .join(', ');
    return 'Create one small real-world activity for a child based on today\'s '
        'aggregate usage. Facts: total screen ${usage.totalMinutes} minutes, '
        'focused ${usage.focusMinutes} minutes, '
        '${usage.breakCount} breaks, categories: $categoryText. '
        'Suggest a screen-free, achievable 15–45 minute activity. '
        'Respond in JSON with keys: answer, observations, recommendations, confidence.';
  }

  String _titleFrom(String answer) {
    final cleaned = answer.replaceAll(RegExp(r'[\[\]{}"]'), '').trim();
    final firstSentence = cleaned.split(RegExp(r'[.\n]')).first.trim();
    final words = firstSentence.split(' ');
    if (words.length > 8) {
      return '${words.take(8).join(' ')}…';
    }
    return firstSentence.isEmpty ? 'Try a mindful activity' : firstSentence;
  }

  int _suggestedMinutes(UsageSummary usage) {
    if (usage.focusMinutes >= 60) return 30;
    if (usage.focusMinutes >= 30) return 20;
    return 15;
  }
}