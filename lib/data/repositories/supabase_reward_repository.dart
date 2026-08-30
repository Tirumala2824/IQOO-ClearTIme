import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reward_model.dart';
import 'local_reward_repository.dart';

/// Durable reward repository. Status changes are database functions rather
/// than client-side field updates so a reward cannot be unlocked prematurely.
class SupabaseRewardRepository implements RewardRepository {
  SupabaseRewardRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _safeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _requireClient => _safeClient ??
      (throw StateError('ClearTime is not connected. Please try again later.'));

  Reward _reward(Map<String, dynamic> row) => Reward(
        id: row['id'] as String,
        parentId: row['parent_user_id'] as String,
        childId: row['child_id'] as String,
        taskId: row['mission_id'] as String,
        title: row['title'] as String,
        description: row['description'] as String?,
        status: RewardStatus.fromString(row['status'] as String?),
        createdAt: row['created_at'] == null ? null : DateTime.parse(row['created_at'] as String),
        unlockedAt: row['unlocked_at'] == null ? null : DateTime.parse(row['unlocked_at'] as String),
        redeemedAt: row['redeemed_at'] == null ? null : DateTime.parse(row['redeemed_at'] as String),
        cancelledAt: row['cancelled_at'] == null ? null : DateTime.parse(row['cancelled_at'] as String),
      );

  @override
  Future<Reward> createReward(Reward reward) async {
    final row = await _requireClient.rpc('create_mission_reward', params: {
      'p_mission_id': reward.taskId,
      'p_title': reward.title.trim(),
      'p_description': reward.description,
    });
    return _reward(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Reward?> getRewardById(String id) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return null;
    final row = await client.from('mission_rewards').select().eq('id', id).maybeSingle();
    return row == null ? null : _reward(Map<String, dynamic>.from(row));
  }

  @override
  Future<Reward?> getRewardForTask(String taskId) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return null;
    final row = await client.from('mission_rewards').select().eq('mission_id', taskId).maybeSingle();
    return row == null ? null : _reward(Map<String, dynamic>.from(row));
  }

  Future<List<Reward>> _list(String column, String id) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client.from('mission_rewards').select().eq(column, id).order('created_at', ascending: false);
    return (rows as List).map((row) => _reward(Map<String, dynamic>.from(row as Map))).toList();
  }

  @override
  Future<List<Reward>> getRewardsForChild(String childId) => _list('child_id', childId);

  @override
  Future<List<Reward>> getRewardsForParent(String parentId) => _list('parent_user_id', parentId);

  @override
  Future<Reward> unlockReward(String rewardId) async {
    final reward = await getRewardById(rewardId);
    if (reward == null) throw ArgumentError('Reward not found.');
    final row = await _requireClient.rpc('unlock_mission_reward', params: {'p_mission_id': reward.taskId});
    return _reward(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Reward> redeemReward(String rewardId) async {
    final row = await _requireClient.rpc('redeem_mission_reward', params: {'p_reward_id': rewardId});
    return _reward(Map<String, dynamic>.from(row as Map));
  }

  @override
  Future<Reward> cancelReward(String rewardId, {required String actorUserId}) =>
      throw UnsupportedError('Reward cancellation needs an audited database command.');
}
