import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/coaching_models.dart';
import '../../../data/models/usage_models.dart';
import '../../../data/repositories/local_mission_repository.dart';
import '../../../data/repositories/local_achievement_repository.dart';
import '../../../core/services/abstractions/notification_provider.dart';

class ChildMissionsState {
  final List<ChildMission> missions;
  final String? activeChildId;
  final bool isLoading;
  final String? errorMessage;

  const ChildMissionsState({
    this.missions = const [],
    this.activeChildId,
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalPoints => missions
      .where((m) => m.isCompleted)
      .fold(0, (sum, m) => sum + m.points);

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
    String? activeChildId,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChildMissionsState(
      missions: missions ?? this.missions,
      activeChildId: activeChildId ?? this.activeChildId,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChildMissionsController extends StateNotifier<ChildMissionsState> {
  final LocalMissionRepository _repository;
  final NotificationProvider _notificationProvider;
  final LocalAchievementRepository _achievementRepository;

  ChildMissionsController({
    required LocalMissionRepository repository,
    required NotificationProvider notificationProvider,
    required LocalAchievementRepository achievementRepository,
  })  : _repository = repository,
        _notificationProvider = notificationProvider,
        _achievementRepository = achievementRepository,
        super(const ChildMissionsState()) {
    loadMissions();
  }

  Future<void> loadMissions({String? childId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final targetChildId = childId ?? state.activeChildId;
      final list = await _repository.getMissions(childId: targetChildId);
      state = state.copyWith(
        missions: list,
        activeChildId: targetChildId,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> startTask(String missionId) async {
    try {
      await _repository.startMission(missionId);
      await loadMissions();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

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
      );

      final updated = await _repository.getMissionById(missionId);
      await loadMissions();

      if (updated != null) {
        if (updated.status == MissionStatus.submitted) {
          // Alert parent that task is submitted for review
          await _notificationProvider.showParentAlertNotification(
            id: missionId.hashCode.abs(),
            title: 'Mission Submitted for Review 📋',
            body:
                '${updated.assignedToChildNickname ?? "Child"} completed "${updated.title}". Tap to review proof.',
          );
        } else if (updated.status == MissionStatus.approved) {
          // Direct completion celebration
          await _notificationProvider.showChildWellbeingNotification(
            id: missionId.hashCode.abs(),
            title: 'Mission Complete! 🌟🎉',
            body:
                'Awesome job completing "${updated.title}"! +${updated.points} XP earned.${updated.reward != null ? " Reward: ${updated.reward}" : ""}',
          );

          // Update achievements
          await _achievementRepository.updateAchievementProgress(
            'ach-focus-starter',
            updated.targetMinutes,
            true,
          );
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
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
      await _notificationProvider.showChildWellbeingNotification(
        id: id.hashCode.abs(),
        title: 'Mission Complete! 🌟',
        body: 'Great job completing "${mission.title}"! +${mission.points} XP earned.',
      );
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
  final notif = ref.watch(notificationProvider);
  final achRepo = ref.watch(localAchievementRepositoryProvider);
  return ChildMissionsController(
    repository: repo,
    notificationProvider: notif,
    achievementRepository: achRepo,
  );
});
