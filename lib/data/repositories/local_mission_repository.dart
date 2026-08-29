import '../models/mission_model.dart';
import '../models/coaching_models.dart';
import '../models/usage_models.dart';

abstract class LocalMissionRepository {
  Future<List<ChildMission>> getMissions({String? childId});
  Future<List<ChildMission>> getMissionsForParent({
    String? parentId,
    String? familyId,
  });
  Future<ChildMission?> getMissionById(String id);
  Future<void> saveMission(ChildMission mission);
  Future<void> createParentTask(ChildMission task);
  Future<void> startMission(String id);
  Future<void> submitMission(
    String id, {
    String? mediaPath,
    String? mediaType,
    String? notes,
  });
  Future<void> approveMission(String id, {String? parentFeedback});
  Future<void> rejectMissionNeedsRetry(
    String id, {
    required String feedback,
  });
  Future<void> deleteMission(String id);
  Future<void> updateMissionProgress(String id, int minutes);
  Future<void> completeMission(String id);
  Future<void> resetDailyMissions();
  Future<void> checkAndExpireMissions();
  Future<List<ChildMission>> generateDynamicMissions({
    required UsageSummary usage,
    required List<DetectedPattern> patterns,
  });
}

class InMemoryLocalMissionRepository implements LocalMissionRepository {
  final Map<String, ChildMission> _missions = {};

  InMemoryLocalMissionRepository();

  void _checkExpirations() {
    final now = DateTime.now();
    for (final entry in _missions.entries) {
      final m = entry.value;
      if (m.dueDate != null &&
          now.isAfter(m.dueDate!) &&
          m.status != MissionStatus.approved &&
          m.status != MissionStatus.expired) {
        _missions[entry.key] = m.copyWith(status: MissionStatus.expired);
      }
    }
  }

  @override
  Future<List<ChildMission>> getMissions({String? childId}) async {
    _checkExpirations();
    if (childId == null || childId.isEmpty) {
      return _missions.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return _missions.values
        .where((m) =>
            m.assignedToChildId == null ||
            m.assignedToChildId == childId ||
            m.assignedToChildId!.isEmpty)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<List<ChildMission>> getMissionsForParent({
    String? parentId,
    String? familyId,
  }) async {
    _checkExpirations();
    return _missions.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<ChildMission?> getMissionById(String id) async {
    _checkExpirations();
    return _missions[id];
  }

  @override
  Future<void> saveMission(ChildMission mission) async {
    _missions[mission.id] = mission;
  }

  @override
  Future<void> createParentTask(ChildMission task) async {
    _missions[task.id] = task;
  }

  @override
  Future<void> startMission(String id) async {
    final existing = _missions[id];
    if (existing == null) {
      throw ArgumentError('Mission with ID $id not found.');
    }
    if (existing.isCompleted) {
      throw StateError('Cannot start already completed mission.');
    }
    if (existing.isExpired) {
      throw StateError('Cannot start expired mission.');
    }

    _missions[id] = existing.copyWith(
      status: MissionStatus.started,
      startedAt: DateTime.now(),
    );
  }

  @override
  Future<void> submitMission(
    String id, {
    String? mediaPath,
    String? mediaType,
    String? notes,
  }) async {
    final existing = _missions[id];
    if (existing == null) {
      throw ArgumentError('Mission with ID $id not found.');
    }

    final now = DateTime.now();

    // If proof requirement requires parent approval or media, set to submitted.
    // If no proof and no parent approval required, immediately approve/complete.
    final bool requiresReview = existing.requiresParentApproval ||
        existing.proofRequirement == ProofRequirement.photo ||
        existing.proofRequirement == ProofRequirement.video;

    if (requiresReview) {
      _missions[id] = existing.copyWith(
        status: MissionStatus.submitted,
        proofMediaPath: mediaPath ?? existing.proofMediaPath,
        proofMediaType: mediaType ?? existing.proofMediaType,
        submissionNotes: notes ?? existing.submissionNotes,
        submittedAt: now,
      );
    } else {
      _missions[id] = existing.copyWith(
        status: MissionStatus.approved,
        currentMinutes: existing.targetMinutes,
        submissionNotes: notes ?? existing.submissionNotes,
        submittedAt: now,
        approvedAt: now,
        completedAt: now,
      );
    }
  }

  @override
  Future<void> approveMission(String id, {String? parentFeedback}) async {
    final existing = _missions[id];
    if (existing == null) {
      throw ArgumentError('Mission with ID $id not found.');
    }

    final now = DateTime.now();
    _missions[id] = existing.copyWith(
      status: MissionStatus.approved,
      currentMinutes: existing.targetMinutes,
      approvedAt: now,
      completedAt: now,
      parentFeedback: parentFeedback ?? existing.parentFeedback,
    );
  }

  @override
  Future<void> rejectMissionNeedsRetry(
    String id, {
    required String feedback,
  }) async {
    final existing = _missions[id];
    if (existing == null) {
      throw ArgumentError('Mission with ID $id not found.');
    }

    _missions[id] = existing.copyWith(
      status: MissionStatus.needsRetry,
      parentFeedback: feedback,
    );
  }

  @override
  Future<void> deleteMission(String id) async {
    _missions.remove(id);
  }

  @override
  Future<void> updateMissionProgress(String id, int minutes) async {
    final existing = _missions[id];
    if (existing == null) return;

    final newMinutes =
        (existing.currentMinutes + minutes).clamp(0, existing.targetMinutes);
    final isDone = newMinutes >= existing.targetMinutes;

    _missions[id] = existing.copyWith(
      currentMinutes: newMinutes,
      status: isDone ? MissionStatus.approved : MissionStatus.started,
      completedAt: isDone ? DateTime.now() : null,
      approvedAt: isDone ? DateTime.now() : null,
    );
  }

  @override
  Future<void> completeMission(String id) async {
    final existing = _missions[id];
    if (existing == null) return;

    final now = DateTime.now();
    _missions[id] = existing.copyWith(
      currentMinutes: existing.targetMinutes,
      status: MissionStatus.approved,
      completedAt: now,
      approvedAt: now,
    );
  }

  @override
  Future<void> resetDailyMissions() async {
    _missions.clear();
  }

  @override
  Future<void> checkAndExpireMissions() async {
    _checkExpirations();
  }

  @override
  Future<List<ChildMission>> generateDynamicMissions({
    required UsageSummary usage,
    required List<DetectedPattern> patterns,
  }) async {
    // Returns current missions without generating fake data
    _checkExpirations();
    return _missions.values.toList();
  }
}
