import '../models/goal_model.dart';

abstract class LocalGoalRepository {
  Future<List<ChildGoal>> getGoals();
  Future<ChildGoal?> getGoalById(String id);
  Future<void> saveGoal(ChildGoal goal);
  Future<void> updateGoalProgress(String id, int minutes);
  Future<void> updateGoalStatus(String id, GoalStatus status);
  Future<void> deleteGoal(String id);
  Future<ChildGoal?> getActiveAIGoal();
  Future<List<ChildGoal>> getGoalHistory();
}

class InMemoryLocalGoalRepository implements LocalGoalRepository {
  final Map<String, ChildGoal> _goals = {};

  InMemoryLocalGoalRepository({bool seedAiHistory = false}) {
    _initDefaultGoals(seedAiHistory: seedAiHistory);
  }

  void _initDefaultGoals({bool seedAiHistory = false}) {
    final now = DateTime.now();

    // User-created goals (existing defaults)
    final userGoals = [
      ChildGoal(
        id: 'g-daily-focus',
        title: 'Daily Focus Goal',
        description: 'Achieve at least 60 minutes of undistracted learning each day.',
        type: GoalType.dailyFocus,
        targetMinutes: 60,
        currentMinutes: 0,
        status: GoalStatus.active,
        source: GoalSource.userCreated,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
      ChildGoal(
        id: 'g-break-goal',
        title: 'Mindful Break Habit',
        description: 'Take at least 4 mindful screen breaks today.',
        type: GoalType.breakGoal,
        targetMinutes: 4,
        currentMinutes: 0,
        status: GoalStatus.active,
        source: GoalSource.userCreated,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      ChildGoal(
        id: 'g-weekly-focus',
        title: 'Weekly Learning Target',
        description: 'Reach 350 minutes of creative and educational app time this week.',
        type: GoalType.weeklyFocus,
        targetMinutes: 350,
        currentMinutes: 0,
        status: GoalStatus.active,
        source: GoalSource.userCreated,
        createdAt: now.subtract(const Duration(days: 5)),
      ),
      ChildGoal(
        id: 'g-balance-goal',
        title: 'Digital Balance',
        description: 'Keep recreational gaming under 60 minutes daily.',
        type: GoalType.digitalBalance,
        targetMinutes: 60,
        currentMinutes: 0,
        status: GoalStatus.active,
        source: GoalSource.userCreated,
        createdAt: now,
      ),
    ];

    for (final g in userGoals) {
      _goals[g.id] = g;
    }
  }

  @override
  Future<List<ChildGoal>> getGoals() async {
    return _goals.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ChildGoal?> getGoalById(String id) async {
    return _goals[id];
  }

  @override
  Future<void> saveGoal(ChildGoal goal) async {
    _goals[goal.id] = goal;
  }

  @override
  Future<void> updateGoalProgress(String id, int minutes) async {
    final existing = _goals[id];
    if (existing == null) return;

    final updatedMinutes = minutes;
    final isDone = updatedMinutes >= existing.targetMinutes;

    _goals[id] = existing.copyWith(
      currentMinutes: updatedMinutes,
      status: isDone ? GoalStatus.completed : existing.status,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> updateGoalStatus(String id, GoalStatus status) async {
    final existing = _goals[id];
    if (existing == null) return;

    _goals[id] = existing.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals.remove(id);
  }

  @override
  Future<ChildGoal?> getActiveAIGoal() async {
    final aiGoals = _goals.values
        .where((g) =>
            g.source == GoalSource.aiGenerated &&
            g.status == GoalStatus.active)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return aiGoals.isNotEmpty ? aiGoals.first : null;
  }

  @override
  Future<List<ChildGoal>> getGoalHistory() async {
    return _goals.values
        .where((g) => g.status == GoalStatus.completed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}

