import '../models/llm_models.dart';

abstract class LocalPromptRepository {
  Future<List<PromptDefinition>> getAllPrompts();
  Future<PromptDefinition?> getPromptById(String id);
  Future<PromptDefinition?> getActivePromptByType(PromptType type);
  Future<PromptDefinition> savePrompt(PromptDefinition prompt, {String changeNotes = ''});
  Future<void> activatePrompt(String id);
  Future<void> deactivatePrompt(String id);
  Future<PromptDefinition> duplicatePrompt(String id);
  Future<PromptDefinition> resetToDefault(PromptType type);
  Future<void> resetAllToDefaults();
  Future<List<PromptVersion>> getVersionHistory(String promptId);
  Future<PromptDefinition> rollbackToVersion(String promptId, int targetVersion);
}

class InMemoryLocalPromptRepository implements LocalPromptRepository {
  final Map<String, PromptDefinition> _prompts = {};
  final Map<String, List<PromptVersion>> _history = {};

  InMemoryLocalPromptRepository() {
    _seedDefaults();
  }

  void _seedDefaults() {
    final now = DateTime.now();

    final defaults = [
      PromptDefinition(
        id: 'prompt-child-insight',
        name: 'Child Daily Insight',
        type: PromptType.childInsight,
        content:
            'You are ClearTime Buddy, a kind, encouraging on-device coach for {{child_name}}.\nToday {{child_name}} used {{screen_time}} with {{focus_time}} of focused study.\nUsage changed by {{usage_change}} compared to yesterday.\nTop category was {{top_category}}.\nCelebrate mindful choices, encourage healthy eye pauses, and never use shame or punishment.',
        version: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        supportedVariables: ['child_name', 'screen_time', 'focus_time', 'usage_change', 'top_category'],
      ),
      PromptDefinition(
        id: 'prompt-child-mission',
        name: 'Child Quest Generator',
        type: PromptType.childMission,
        content:
            'You are an exciting adventure quest-master for {{child_name}}.\nTop category today is {{top_category}} and current goal progress is {{goal_progress}}.\nSuggest 2 fun, screen-free quests or mindful movement challenges (like a 15-minute nature walk or drawing quest). Keep it uplifting!',
        version: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        supportedVariables: ['child_name', 'top_category', 'goal_progress', 'completed_missions'],
      ),
      PromptDefinition(
        id: 'prompt-child-reflection',
        name: 'Child Mindful Reflection',
        type: PromptType.childReflection,
        content:
            'Hi {{child_name}}! 🌿 Take a peaceful breath.\nYou spent {{focus_time}} on mindful learning today with {{break_count}} pauses.\nHow did today feel? What was something fun you discovered?',
        version: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        supportedVariables: ['child_name', 'focus_time', 'break_count'],
      ),
      PromptDefinition(
        id: 'prompt-parent-report',
        name: 'Parent Report Summary',
        type: PromptType.parentReport,
        content:
            'Analyze the approved summary facts for {{child_name}} on {{report_date}}:\n- Recorded Screen Time: {{screen_time}}\n- Focus Time: {{focus_time}}\n- Usage Change: {{usage_change}}\n- Primary Category: {{top_category}}\n- Goal Progress: {{goal_progress}}\n\nProvide an objective, non-alarmist summary with actionable habit coaching suggestions.',
        version: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        supportedVariables: ['child_name', 'report_date', 'screen_time', 'focus_time', 'usage_change', 'top_category', 'goal_progress'],
      ),
      PromptDefinition(
        id: 'prompt-parent-chat',
        name: 'Parent Query Assistant',
        type: PromptType.parentChat,
        content:
            'You are a privacy-safe, local parenting assistant.\nAnswer parent questions about {{child_name}}\'s digital habits strictly using approved report facts: Screen time {{screen_time}}, Focus time {{focus_time}}, Goals progress {{goal_progress}}.\nNever guess raw application details or hidden reflections. Clearly state if data is not available.',
        version: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        supportedVariables: ['child_name', 'screen_time', 'focus_time', 'goal_progress', 'top_category'],
      ),
      PromptDefinition(
        id: 'prompt-parent-trigger',
        name: 'Parent Trigger Explanation',
        type: PromptType.parentTriggerExplanation,
        content:
            'A digital habit threshold was reached for {{child_name}}:\nRecorded Screen Time: {{screen_time}} (Change: {{usage_change}}).\nExplain the trend factually and provide positive conversation starters for dinner discussions.',
        version: 1,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        supportedVariables: ['child_name', 'screen_time', 'usage_change', 'top_category'],
      ),
    ];

    for (final p in defaults) {
      _prompts[p.id] = p;
      _history[p.id] = [
        PromptVersion(
          promptId: p.id,
          version: 1,
          content: p.content,
          createdAt: p.createdAt,
          changeNotes: 'Initial default version',
        ),
      ];
    }
  }

  @override
  Future<List<PromptDefinition>> getAllPrompts() async {
    return _prompts.values.toList();
  }

  @override
  Future<PromptDefinition?> getPromptById(String id) async {
    return _prompts[id];
  }

  @override
  Future<PromptDefinition?> getActivePromptByType(PromptType type) async {
    try {
      return _prompts.values.firstWhere(
        (p) => p.type == type && p.isActive,
      );
    } catch (_) {
      try {
        return _prompts.values.firstWhere((p) => p.type == type);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<PromptDefinition> savePrompt(
    PromptDefinition prompt, {
    String changeNotes = '',
  }) async {
    final existing = _prompts[prompt.id];
    final newVersion = (existing?.version ?? 0) + 1;
    final now = DateTime.now();

    final updated = prompt.copyWith(
      version: newVersion,
      updatedAt: now,
    );

    _prompts[prompt.id] = updated;

    final historyList = _history[prompt.id] ?? [];
    historyList.add(
      PromptVersion(
        promptId: prompt.id,
        version: newVersion,
        content: prompt.content,
        createdAt: now,
        changeNotes: changeNotes.isNotEmpty ? changeNotes : 'Updated version $newVersion',
      ),
    );
    _history[prompt.id] = historyList;

    return updated;
  }

  @override
  Future<void> activatePrompt(String id) async {
    final target = _prompts[id];
    if (target == null) return;

    // Deactivate others of same type
    for (final key in _prompts.keys) {
      if (_prompts[key]!.type == target.type && key != id) {
        _prompts[key] = _prompts[key]!.copyWith(isActive: false);
      }
    }

    _prompts[id] = target.copyWith(isActive: true);
  }

  @override
  Future<void> deactivatePrompt(String id) async {
    final target = _prompts[id];
    if (target != null) {
      _prompts[id] = target.copyWith(isActive: false);
    }
  }

  @override
  Future<PromptDefinition> duplicatePrompt(String id) async {
    final original = _prompts[id];
    if (original == null) {
      throw ArgumentError('Prompt not found: $id');
    }

    final newId = 'prompt-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now();
    final duplicate = original.copyWith(
      id: newId,
      name: '${original.name} (Copy)',
      version: 1,
      isActive: false,
      createdAt: now,
      updatedAt: now,
    );

    _prompts[newId] = duplicate;
    _history[newId] = [
      PromptVersion(
        promptId: newId,
        version: 1,
        content: duplicate.content,
        createdAt: now,
        changeNotes: 'Duplicated from ${original.name}',
      ),
    ];

    return duplicate;
  }

  @override
  Future<PromptDefinition> resetToDefault(PromptType type) async {
    final defaultId = 'prompt-${type.name}';
    _seedDefaults();
    return _prompts[defaultId] ??
        _prompts.values.firstWhere((p) => p.type == type);
  }

  @override
  Future<void> resetAllToDefaults() async {
    _prompts.clear();
    _history.clear();
    _seedDefaults();
  }

  @override
  Future<List<PromptVersion>> getVersionHistory(String promptId) async {
    return _history[promptId] ?? [];
  }

  @override
  Future<PromptDefinition> rollbackToVersion(String promptId, int targetVersion) async {
    final prompt = _prompts[promptId];
    if (prompt == null) {
      throw ArgumentError('Prompt not found: $promptId');
    }

    final history = _history[promptId] ?? [];
    final historical = history.firstWhere(
      (v) => v.version == targetVersion,
      orElse: () => throw ArgumentError('Version $targetVersion not found for prompt $promptId'),
    );

    return await savePrompt(
      prompt.copyWith(content: historical.content),
      changeNotes: 'Rolled back to v$targetVersion',
    );
  }
}
