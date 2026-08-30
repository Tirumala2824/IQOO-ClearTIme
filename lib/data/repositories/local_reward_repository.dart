import '../models/reward_model.dart';

/// Thrown when a reward state transition violates the reward business rules.
class RewardStateError extends StateError {
  RewardStateError(super.message);
}

abstract class RewardRepository {
  /// Creates the reward in [RewardStatus.locked] state.
  Future<Reward> createReward(Reward reward);

  Future<Reward?> getRewardById(String id);

  /// Returns the reward attached to a task, if any.
  Future<Reward?> getRewardForTask(String taskId);

  Future<List<Reward>> getRewardsForChild(String childId);

  Future<List<Reward>> getRewardsForParent(String parentId);

  /// [locked] -> [unlocked]. Only allowed when the reward is locked.
  Future<Reward> unlockReward(String rewardId);

  /// [unlocked] -> [redeemed]. Persists [redeemedAt]. Only allowed when unlocked.
  Future<Reward> redeemReward(String rewardId);

  /// Authorized cancellation. Only allowed while not already terminal.
  Future<Reward> cancelReward(String rewardId, {required String actorUserId});
}

class InMemoryRewardRepository implements RewardRepository {
  final Map<String, Reward> _rewards = {};

  @override
  Future<Reward> createReward(Reward reward) async {
    if (_rewards.containsKey(reward.id)) {
      throw RewardStateError('Reward with ID ${reward.id} already exists.');
    }
    // Rewards always start locked; unlocking is a business event, not creation.
    final locked = reward.status == RewardStatus.locked
        ? reward
        : Reward(
            id: reward.id,
            parentId: reward.parentId,
            childId: reward.childId,
            taskId: reward.taskId,
            title: reward.title,
            description: reward.description,
            status: RewardStatus.locked,
            createdAt: reward.createdAt,
          );
    _rewards[locked.id] = locked;
    return locked;
  }

  @override
  Future<Reward?> getRewardById(String id) async => _rewards[id];

  @override
  Future<Reward?> getRewardForTask(String taskId) async {
    for (final r in _rewards.values) {
      if (r.taskId == taskId) return r;
    }
    return null;
  }

  @override
  Future<List<Reward>> getRewardsForChild(String childId) async =>
      _rewards.values.where((r) => r.childId == childId).toList()
        ..sort((a, b) => b.createdDate.compareTo(a.createdDate));

  @override
  Future<List<Reward>> getRewardsForParent(String parentId) async =>
      _rewards.values.where((r) => r.parentId == parentId).toList()
        ..sort((a, b) => b.createdDate.compareTo(a.createdDate));

  @override
  Future<Reward> unlockReward(String rewardId) async {
    final reward = _rewards[rewardId];
    if (reward == null) {
      throw ArgumentError('Reward with ID $rewardId not found.');
    }
    if (reward.status != RewardStatus.locked) {
      throw RewardStateError(
        'Reward $rewardId cannot be unlocked from status "${reward.status.name}".',
      );
    }
    final unlocked = reward.copyWith(
      status: RewardStatus.unlocked,
      unlockedAt: DateTime.now(),
    );
    _rewards[rewardId] = unlocked;
    return unlocked;
  }

  @override
  Future<Reward> redeemReward(String rewardId) async {
    final reward = _rewards[rewardId];
    if (reward == null) {
      throw ArgumentError('Reward with ID $rewardId not found.');
    }
    if (reward.status != RewardStatus.unlocked) {
      throw RewardStateError(
        'Reward $rewardId cannot be redeemed from status "${reward.status.name}".',
      );
    }
    final redeemed = reward.copyWith(
      status: RewardStatus.redeemed,
      redeemedAt: DateTime.now(),
    );
    _rewards[rewardId] = redeemed;
    return redeemed;
  }

  @override
  Future<Reward> cancelReward(
    String rewardId, {
    required String actorUserId,
  }) async {
    final reward = _rewards[rewardId];
    if (reward == null) {
      throw ArgumentError('Reward with ID $rewardId not found.');
    }
    // Only the authorizing parent may cancel.
    if (reward.parentId != actorUserId) {
      throw ArgumentError('User $actorUserId is not authorized to cancel this reward.');
    }
    if (reward.status == RewardStatus.cancelled ||
        reward.status == RewardStatus.redeemed) {
      throw RewardStateError(
        'Reward $rewardId is already in terminal status "${reward.status.name}".',
      );
    }
    final cancelled = reward.copyWith(
      status: RewardStatus.cancelled,
      cancelledAt: DateTime.now(),
    );
    _rewards[rewardId] = cancelled;
    return cancelled;
  }
}
