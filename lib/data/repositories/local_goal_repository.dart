import '../models/goal_model.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class LocalGoalRepository {
  Future<List<ChildGoal>> getGoals();
  Future<ChildGoal?> getGoalById(String id);
  Future<void> saveGoal(ChildGoal goal);
  Future<void> updateGoalProgress(String id, int minutes);
  Future<void> updateGoalStatus(String id, GoalStatus status);
  Future<void> deleteGoal(String id);
  Future<ChildGoal?> getActiveAIGoal();
  Future<List<ChildGoal>> getGoalHistory();
  Future<bool> hasActiveAIGoalForToday(GoalType type);
}

/// Encrypted on-device persistence for private child goals.
///
/// Goals never sync to Supabase; they exist only inside the encrypted store
/// and are generated solely from real usage aggregates.
class EncryptedLocalGoalRepository implements LocalGoalRepository {
  final EncryptedDeviceStore _store;

  EncryptedLocalGoalRepository({required EncryptedDeviceStore store})
      : _store = store;

  @override
  Future<List<ChildGoal>> getGoals() async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.goalsBox,
      onCorrupt: (key, _) => deleteGoal(key),
    );
    final goals = <ChildGoal>[];
    for (final json in jsons) {
      try {
        goals.add(ChildGoal.fromJson(json));
      } catch (_) {
        // Skip corrupted entries; they are surfaced as an empty result.
      }
    }
    // Retire goals whose validity window has passed.
    for (final goal in goals.where((g) =>
        g.status == GoalStatus.active && g.expiresAt != null && g.isExpired)) {
      await saveGoal(goal.copyWith(
        status: GoalStatus.expired,
        updatedAt: DateTime.now(),
      ));
    }
    goals.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return goals;
  }

  /// True when an AI-generated goal for the same type already exists for
  /// today and is neither finished nor expired — prevents duplicate daily
  /// suggestions.
  @override
  Future<bool> hasActiveAIGoalForToday(GoalType type) async {
    final goals = await getGoals();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return goals.any((g) =>
        g.source == GoalSource.aiGenerated &&
        g.type == type &&
        g.status != GoalStatus.completed &&
        g.status != GoalStatus.expired &&
        g.createdAt.year == today.year &&
        g.createdAt.month == today.month &&
        g.createdAt.day == today.day);
  }

  @override
  Future<ChildGoal?> getGoalById(String id) async {
    final json = await _store.getJson(EncryptedDeviceStore.goalsBox, id);
    if (json == null) return null;
    try {
      return ChildGoal.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveGoal(ChildGoal goal) async {
    await _store.putJson(EncryptedDeviceStore.goalsBox, goal.id, goal.toJson());
  }

  @override
  Future<void> updateGoalProgress(String id, int minutes) async {
    final existing = await getGoalById(id);
    if (existing == null) return;

    final updatedMinutes = minutes;
    final isDone = updatedMinutes >= existing.targetMinutes;

    await saveGoal(existing.copyWith(
      currentMinutes: updatedMinutes,
      status: isDone ? GoalStatus.completed : existing.status,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> updateGoalStatus(String id, GoalStatus status) async {
    final existing = await getGoalById(id);
    if (existing == null) return;

    await saveGoal(existing.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    ));
  }

  @override
  Future<void> deleteGoal(String id) async {
    await _store.delete(EncryptedDeviceStore.goalsBox, id);
  }

  @override
  Future<ChildGoal?> getActiveAIGoal() async {
    final goals = await getGoals();
    final aiGoals = goals
        .where((g) =>
            g.source == GoalSource.aiGenerated &&
            g.status == GoalStatus.active)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return aiGoals.isNotEmpty ? aiGoals.first : null;
  }

  @override
  Future<List<ChildGoal>> getGoalHistory() async {
    final goals = await getGoals();
    return goals
        .where((g) => g.status == GoalStatus.completed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }
}
