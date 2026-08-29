import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/goal_model.dart';
import 'package:cleartime/data/models/achievement_model.dart';
import 'package:cleartime/data/repositories/local_mission_repository.dart';
import 'package:cleartime/data/repositories/local_goal_repository.dart';
import 'package:cleartime/data/repositories/local_achievement_repository.dart';

void main() {
  group('Missions, Goals, and Achievements On-Device Unit Tests', () {
    test('LocalMissionRepository progresses and completes missions dynamically', () async {
      final repo = InMemoryLocalMissionRepository();
      final missions = await repo.getMissions();
      expect(missions.isNotEmpty, isTrue);

      final studyMission = missions.firstWhere((m) => m.id == 'm-study-sprint');
      expect(studyMission.isCompleted, isFalse);

      // Add 10 minutes progress to 25-min mission (was at 15m) -> 25m -> completed
      await repo.updateMissionProgress('m-study-sprint', 10);
      final updated = await repo.getMissionById('m-study-sprint');
      expect(updated?.isCompleted, isTrue);
      expect(updated?.status, equals(MissionStatus.completed));
      expect(updated?.completedAt, isNotNull);
    });

    test('LocalGoalRepository creates, updates, and pauses goals', () async {
      final repo = InMemoryLocalGoalRepository();
      final now = DateTime.now();

      final newGoal = ChildGoal(
        id: 'g-custom-reading',
        title: 'Daily Reading',
        description: 'Read 20 minutes',
        type: GoalType.dailyFocus,
        targetMinutes: 20,
        currentMinutes: 10,
        createdAt: now,
      );

      await repo.saveGoal(newGoal);
      expect((await repo.getGoals()).length, equals(5));

      // Update progress to 20m -> should complete
      await repo.updateGoalProgress('g-custom-reading', 20);
      final completedGoal = await repo.getGoalById('g-custom-reading');
      expect(completedGoal?.isCompleted, isTrue);
      expect(completedGoal?.status, equals(GoalStatus.completed));

      // Pause goal
      await repo.updateGoalStatus('g-custom-reading', GoalStatus.paused);
      expect((await repo.getGoalById('g-custom-reading'))?.status, equals(GoalStatus.paused));
    });

    test('LocalAchievementRepository updates badge progress and unlock timestamps', () async {
      final repo = InMemoryLocalAchievementRepository();
      final achievements = await repo.getAchievements();

      final balanceAch = achievements.firstWhere((a) => a.type == AchievementType.sevenDayBalance);
      expect(balanceAch.isUnlocked, isFalse);

      // Progress to 7 days
      await repo.updateAchievementProgress(balanceAch.id, 7, true);
      final unlocked = await repo.getAchievementById(balanceAch.id);
      expect(unlocked?.isUnlocked, isTrue);
      expect(unlocked?.unlockedAt, isNotNull);
      expect(unlocked?.progress, equals(1.0));
    });
  });
}
