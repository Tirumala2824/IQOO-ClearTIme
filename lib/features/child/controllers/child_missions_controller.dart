import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/services/task_notification_service.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/reward_model.dart';
import '../../../data/models/coaching_models.dart';
import '../../../data/models/usage_models.dart';
import '../../../data/repositories/local_mission_repository.dart';
import '../../../data/repositories/local_reward_repository.dart';
import '../../../data/repositories/local_achievement_repository.dart';

class ChildMissionsState {
  final List<ChildMission> missions;
  final List<Reward> rewards;
  final String? activeChildId;
  final bool isLoading;
  final String? errorMessage;

  const ChildMissionsState({
    this.missions = const [],
    this.rewards = const [],
    this.activeChildId,
    this.isLoading = false,
    this.errorMessage,
  });

  int get availableCount => missions
      .where((m) =>
          m.status == MissionStatus.assigned ||
          m.status == MissionStatus.started ||
          m.status == MissionStatus.needsRetry)
      .length;

  int get completedCount => missions.where((m) => m.isCompleted).length;

  List<ChildMission> get activeMissions => missions
      .where((m) =>
          m.status == MissionStatus.assigned ||
          m.status == MissionStatus.started ||
          m.status == MissionStatus.needsRetry)
      .toList();

  List<ChildMission> get submittedMissions =>
      missions.where((m) => m.status == MissionStatus.submitted).toList();

  List<ChildMission> get completedMissions =>
      missions.where((m) => m.status == MissionStatus.approved).toList();

  ChildMissionsState copyWith({
    List<ChildMission>? missions,
    List<Reward>? rewards,
    String? activeChildId,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChildMissionsState(
      missions: missions ?? this.missions,
      rewards: rewards ?? this.rewards,
      activeChildId: activeChildId ?? this.activeChildId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChildMissionsController extends StateNotifier<ChildMissionsState> {
  final LocalMissionRepository _repository;
  final RewardRepository _rewardRepository;
  final TaskNotificationService _taskNotifications;
  final LocalAchievementRepository _achievementRepository;

  ChildMissionsController({
    required LocalMissionRepository repository,
    required RewardRepository rewardRepository,
    required TaskNotificationService taskNotifications,
    required LocalAchievementRepository achievementRepository,
  })  : _repository = repository,
        _rewardRepository = rewardRepository,
        _taskNotifications = taskNotifications,
        _achievementRepository = achievementRepository,
        super(const ChildMissionsState()) {
    loadMissions();
  }

  Future<void> loadMissions({String? childId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final targetChildId = (childId != null && childId.isNotEmpty)
          ? childId
          : state.activeChildId;
      final list = await _repository.getMissions(childId: targetChildId);
      final effectiveChildId = targetChildId ??
          (list.isNotEmpty ? list.first.assignedToChildId : null);

      final rewards = effectiveChildId == null
          ? const <Reward>[]
          : await _rewardRepository.getRewardsForChild(effectiveChildId);

      state = state.copyWith(
        missions: list,
        rewards: rewards,
        activeChildId: effectiveChildId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  /// Real lifecycle transition [assigned|needsRetry] -> [started], performed
  /// only on an explicit child action. Generates [TASK_STARTED] for the
  /// assigned parent only after the state change persisted successfully.
  Future<void> startTask(String missionId) async {
    try {
      // Ownership validation: only the assigned child can start the task.
      await _repository.startMission(missionId, childId: state.activeChildId);

      final updated = await _repository.getMissionById(missionId);
      await loadMissions();

      if (updated != null) {
        final delivered = await _taskNotifications.notifyTaskStarted(updated);
        if (!delivered) {
          // Persisted state is authoritative; surface delivery failure
          // truthfully without rolling back the real start action.
          state = state.copyWith(
            errorMessage:
                'Task started, but the parent notification could not be delivered.',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Real lifecycle transition [started] -> [submitted] (or straight to
  /// [approved] when the task config requires no review). Enforces the
  /// configured proof requirements and generates [TASK_COMPLETED] for the
  /// parent only after a successful submission.
  Future<void> submitTask(
    String missionId, {
    String? mediaPath,
    String? mediaType,
    String? notes,
  }) async {
    try {
      await _repository.submitMission(
        missionId,
        mediaPath: mediaPath,
        mediaType: mediaType,
        notes: notes,
        childId: state.activeChildId,
      );

      final updated = await _repository.getMissionById(missionId);
      await loadMissions();

      if (updated == null) return;

      if (updated.status == MissionStatus.submitted) {
        // [TASK_COMPLETED] — parent is informed of the real submission.
        await _taskNotifications.notifyTaskCompleted(updated);
      } else if (updated.status == MissionStatus.approved) {
        // No parent approval required by configuration: the unlock condition
        // is satisfied by the real submission itself.
        await _unlockRewardIfConfigured(updated);
        await _taskNotifications.notifyTaskApproved(
          task: updated,
          unlockedReward: await _rewardRepository.getRewardForTask(updated.id),
        );

        // Update achievements through the existing business logic.
        await _achievementRepository.updateAchievementProgress(
          'ach-focus-starter',
          updated.targetMinutes,
          true,
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> _unlockRewardIfConfigured(ChildMission approvedTask) async {
    final reward = await _rewardRepository.getRewardForTask(approvedTask.id);
    if (reward == null || !reward.isLocked) return;

    try {
      final unlocked = await _rewardRepository.unlockReward(reward.id);
      await _taskNotifications.notifyRewardUnlocked(
        reward: unlocked,
        childNickname: approvedTask.assignedToChildNickname ?? 'Hey',
      );
      await _reloadRewards();
    } catch (e) {
      // Reward unlock failure must not fake success.
      state = state.copyWith(
        errorMessage: 'Reward could not be unlocked: ${e.toString()}',
      );
    }
  }

  Future<void> _reloadRewards() async {
    final childId = state.activeChildId;
    if (childId == null) return;
    state = state.copyWith(
      rewards: await _rewardRepository.getRewardsForChild(childId),
    );
  }

  /// Real redemption action performed by the child/family:
  /// [unlocked] -> [redeemed]. Never happens automatically.
  Future<void> redeemReward(String rewardId) async {
    try {
      await _rewardRepository.redeemReward(rewardId);
      await _reloadRewards();
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Reward could not be redeemed: ${e.toString()}',
      );
    }
  }

  Future<void> toggleMission(String id) async {
    final mission = await _repository.getMissionById(id);
    if (mission == null) return;

    if (mission.isCompleted) {
      await _repository.saveMission(
        mission.copyWith(
          status: MissionStatus.assigned,
          currentMinutes: 0,
        ),
      );
    } else {
      await _repository.completeMission(id);
    }
    await loadMissions();
  }

  Future<void> addProgress(String id, int minutes) async {
    await _repository.updateMissionProgress(id, minutes);
    await loadMissions();
  }

  /// Refreshes missions based on detected patterns and usage.
  Future<void> refreshMissionsFromPatterns({
    required UsageSummary usage,
    required List<DetectedPattern> patterns,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final updated = await _repository.generateDynamicMissions(
        usage: usage,
        patterns: patterns,
      );
      state = state.copyWith(missions: updated, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final childMissionsControllerProvider =
    StateNotifierProvider<ChildMissionsController, ChildMissionsState>((ref) {
  final repo = ref.watch(localMissionRepositoryProvider);
  final rewardRepo = ref.watch(rewardRepositoryProvider);
  final taskNotifications = TaskNotificationService(
    notificationProvider: ref.watch(notificationProvider),
  );
  final achRepo = ref.watch(localAchievementRepositoryProvider);
  return ChildMissionsController(
    repository: repo,
    rewardRepository: rewardRepo,
    taskNotifications: taskNotifications,
    achievementRepository: achRepo,
  );
});
