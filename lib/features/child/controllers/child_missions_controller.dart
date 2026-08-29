import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/repositories/local_mission_repository.dart';

class ChildMissionsState {
  final List<ChildMission> missions;
  final bool isLoading;
  final String? errorMessage;

  const ChildMissionsState({
    this.missions = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get totalPoints => missions
      .where((m) => m.isCompleted)
      .fold(0, (sum, m) => sum + m.points);

  ChildMissionsState copyWith({
    List<ChildMission>? missions,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChildMissionsState(
      missions: missions ?? this.missions,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ChildMissionsController extends StateNotifier<ChildMissionsState> {
  final LocalMissionRepository _repository;

  ChildMissionsController(this._repository) : super(const ChildMissionsState()) {
    loadMissions();
  }

  Future<void> loadMissions() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getMissions();
      state = state.copyWith(missions: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleMission(String id) async {
    final mission = await _repository.getMissionById(id);
    if (mission == null) return;

    if (mission.isCompleted) {
      await _repository.saveMission(
        mission.copyWith(
          status: MissionStatus.available,
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
}

final childMissionsControllerProvider =
    StateNotifierProvider<ChildMissionsController, ChildMissionsState>((ref) {
  final repo = ref.watch(localMissionRepositoryProvider);
  return ChildMissionsController(repo);
});
