import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/usage_models.dart';
import '../../../data/repositories/local_goal_repository.dart';
import '../../../services/coaching/coaching_loop_service.dart';

class ChildGoalsState {
  final List<ChildGoal> goals;
  final ChildGoal? activeAIGoal;
  final bool isLoading;
  final String? errorMessage;

  const ChildGoalsState({
    this.goals = const [],
    this.activeAIGoal,
    this.isLoading = false,
    this.errorMessage,
  });

  int get completedGoalsCount => goals.where((g) => g.isCompleted).length;
  int get aiGoalsCount => goals.where((g) => g.isAIGenerated).length;
  int get userGoalsCount => goals.where((g) => g.source == GoalSource.userCreated).length;

  List<ChildGoal> get activeGoals =>
      goals.where((g) => g.status == GoalStatus.active).toList();
  List<ChildGoal> get completedGoals =>
      goals.where((g) => g.status == GoalStatus.completed).toList();
  List<ChildGoal> get aiGoalHistory =>
      goals.where((g) => g.isAIGenerated && g.status == GoalStatus.completed).toList();

  ChildGoalsState copyWith({
    List<ChildGoal>? goals,
    ChildGoal? activeAIGoal,
    bool? isLoading,
    String? errorMessage,
    bool clearAIGoal = false,
  }) {
    return ChildGoalsState(
      goals: goals ?? this.goals,
      activeAIGoal: clearAIGoal ? null : (activeAIGoal ?? this.activeAIGoal),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ChildGoalsController extends StateNotifier<ChildGoalsState> {
  final LocalGoalRepository _repository;
  final CoachingLoopService _coachingService;

  ChildGoalsController(this._repository, this._coachingService)
      : super(const ChildGoalsState()) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getGoals();
      final aiGoal = await _repository.getActiveAIGoal();
      state = state.copyWith(goals: list, activeAIGoal: aiGoal, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Generates a new AI Goal using the coaching service
  Future<void> generateAIGoal() async {
    state = state.copyWith(isLoading: true);
    try {
      final usage = await _coachingService.collectUsageData();
      final patterns = await _coachingService.detectPatterns(usage);
      final newGoal = await _coachingService.generateGoal(patterns);
      await _repository.saveGoal(newGoal);
      await loadGoals();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> createGoal({
    required String title,
    required String description,
    required GoalType type,
    required int targetMinutes,
  }) async {
    final now = DateTime.now();
    final goal = ChildGoal(
      id: 'g-${now.millisecondsSinceEpoch}',
      title: title,
      description: description,
      type: type,
      targetMinutes: targetMinutes,
      source: GoalSource.userCreated,
      createdAt: now,
    );
    await _repository.saveGoal(goal);
    await loadGoals();
  }

  /// Syncs all active goals with real usage data.
  Future<void> syncWithUsage(UsageSummary usage) async {
    final goals = await _repository.getGoals();
    for (final goal in goals) {
      if (goal.status != GoalStatus.active) continue;

      int actualValue;
      switch (goal.type) {
        case GoalType.dailyFocus:
          actualValue = usage.focusMinutes;
          break;
        case GoalType.breakGoal:
          actualValue = usage.breakCount;
          break;
        case GoalType.digitalBalance:
          final gamingMin = usage.categories
              .where((c) => c.category.toLowerCase().contains('game'))
              .fold<int>(0, (s, c) => s + c.totalMinutes);
          actualValue = gamingMin <= goal.targetMinutes
              ? goal.targetMinutes
              : (goal.targetMinutes - (gamingMin - goal.targetMinutes))
                  .clamp(0, goal.targetMinutes);
          break;
        case GoalType.weeklyFocus:
          actualValue = usage.focusMinutes;
          break;
      }

      await _repository.updateGoalProgress(goal.id, actualValue);
    }
    await loadGoals();
  }

  Future<void> updateProgress(String id, int minutes) async {
    await _repository.updateGoalProgress(id, minutes);
    await loadGoals();
  }

  Future<void> toggleGoalPause(String id) async {
    final goal = await _repository.getGoalById(id);
    if (goal == null) return;

    final newStatus =
        goal.status == GoalStatus.paused ? GoalStatus.active : GoalStatus.paused;
    await _repository.updateGoalStatus(id, newStatus);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await _repository.deleteGoal(id);
    await loadGoals();
  }
}

final childGoalsControllerProvider =
    StateNotifierProvider<ChildGoalsController, ChildGoalsState>((ref) {
  final repo = ref.watch(localGoalRepositoryProvider);
  final coaching = ref.watch(coachingLoopServiceProvider);
  return ChildGoalsController(repo, coaching);
});
