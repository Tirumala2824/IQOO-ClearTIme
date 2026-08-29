import '../models/mission_model.dart';

abstract class LocalMissionRepository {
  Future<List<ChildMission>> getMissions();
  Future<ChildMission?> getMissionById(String id);
  Future<void> saveMission(ChildMission mission);
  Future<void> updateMissionProgress(String id, int minutes);
  Future<void> completeMission(String id);
  Future<void> resetDailyMissions();
}

class InMemoryLocalMissionRepository implements LocalMissionRepository {
  final Map<String, ChildMission> _missions = {};

  InMemoryLocalMissionRepository() {
    _initDefaultMissions();
  }

  void _initDefaultMissions() {
    final defaultList = [
      const ChildMission(
        id: 'm-focus-20',
        title: '20-Minute Focus Quest',
        description: 'Spend 20 minutes on educational learning without distractions.',
        category: 'Learning',
        type: MissionType.focus,
        targetMinutes: 20,
        currentMinutes: 0,
        points: 50,
        status: MissionStatus.available,
      ),
      const ChildMission(
        id: 'm-study-sprint',
        title: 'Study Sprint',
        description: 'Complete an uninterrupted 25-minute study sprint session.',
        category: 'Study',
        type: MissionType.focus,
        targetMinutes: 25,
        currentMinutes: 0,
        points: 60,
        status: MissionStatus.available,
      ),
      const ChildMission(
        id: 'm-break-10',
        title: '10-Minute Screen Break',
        description: 'Step away from all screens and look at the sky or stretch.',
        category: 'Mindful Break',
        type: MissionType.breakMission,
        targetMinutes: 10,
        currentMinutes: 0,
        points: 40,
        status: MissionStatus.available,
      ),
      const ChildMission(
        id: 'm-screen-free-meal',
        title: 'Screen-Free Meal',
        description: 'Enjoy a meal with family or friends without your phone nearby.',
        category: 'Family Connection',
        type: MissionType.breakMission,
        targetMinutes: 30,
        currentMinutes: 0,
        points: 45,
        status: MissionStatus.available,
      ),
      const ChildMission(
        id: 'm-reading-challenge',
        title: 'Reading Explorer Challenge',
        description: 'Read a book or educational article for 15 minutes.',
        category: 'Reading',
        type: MissionType.reading,
        targetMinutes: 15,
        currentMinutes: 0,
        points: 50,
        status: MissionStatus.available,
      ),
    ];

    for (final m in defaultList) {
      _missions[m.id] = m;
    }
  }

  @override
  Future<List<ChildMission>> getMissions() async {
    return _missions.values.toList();
  }

  @override
  Future<ChildMission?> getMissionById(String id) async {
    return _missions[id];
  }

  @override
  Future<void> saveMission(ChildMission mission) async {
    _missions[mission.id] = mission;
  }

  @override
  Future<void> updateMissionProgress(String id, int minutes) async {
    final existing = _missions[id];
    if (existing == null) return;

    final newMinutes = (existing.currentMinutes + minutes).clamp(0, existing.targetMinutes);
    final isDone = newMinutes >= existing.targetMinutes;

    _missions[id] = existing.copyWith(
      currentMinutes: newMinutes,
      status: isDone ? MissionStatus.completed : MissionStatus.inProgress,
      completedAt: isDone ? DateTime.now() : null,
    );
  }

  @override
  Future<void> completeMission(String id) async {
    final existing = _missions[id];
    if (existing == null) return;

    _missions[id] = existing.copyWith(
      currentMinutes: existing.targetMinutes,
      status: MissionStatus.completed,
      completedAt: DateTime.now(),
    );
  }

  @override
  Future<void> resetDailyMissions() async {
    _initDefaultMissions();
  }
}
