import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/repositories/local_goal_repository.dart';

class ChildGoalsState {
  final List<ChildGoal> goals;
  final bool isLoading;
  final String? errorMessage;

  const ChildGoalsState({
    this.goals = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get completedGoalsCount => goals.where((g) => g.isCompleted).length;

  ChildGoalsState copyWith({
    List<ChildGoal>? goals,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChildGoalsState(
      goals: goals ?? this.goals,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ChildGoalsController extends StateNotifier<ChildGoalsState> {
  final LocalGoalRepository _repository;

  ChildGoalsController(this._repository) : super(const ChildGoalsState()) {
    loadGoals();
  }

  Future<void> loadGoals() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getGoals();
      state = state.copyWith(goals: list, isLoading: false);
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
      createdAt: now,
    );
    await _repository.saveGoal(goal);
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
  return ChildGoalsController(repo);
});
