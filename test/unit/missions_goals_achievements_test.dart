import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/goal_model.dart';
import 'package:cleartime/data/models/achievement_model.dart';
import 'package:cleartime/data/repositories/local_mission_repository.dart';
import 'package:cleartime/data/repositories/local_goal_repository.dart';
import 'package:cleartime/data/repositories/local_achievement_repository.dart';
import '../helpers/encrypted_store_helper.dart';

void main() {
  group('Missions, Goals, and Achievements On-Device Unit Tests', () {
    test('LocalMissionRepository starts, progresses, and completes missions dynamically', () async {
      final repo = InMemoryLocalMissionRepository();
      expect((await repo.getMissions()).isEmpty, isTrue);

      final studyMission = ChildMission(
        id: 'm-study-sprint',
        title: 'Study Sprint',
        description: 'Complete 25 minutes of learning',
        targetMinutes: 25,
      );

      await repo.saveMission(studyMission);
      final missions = await repo.getMissions();
      expect(missions.length, equals(1));
      expect(missions.first.isCompleted, isFalse);

      // Add 25 minutes progress to 25-min mission -> 25m -> approved/completed
      await repo.updateMissionProgress('m-study-sprint', 25);
      final updated = await repo.getMissionById('m-study-sprint');
      expect(updated?.isCompleted, isTrue);
      expect(updated?.status, equals(MissionStatus.approved));
      expect(updated?.completedAt, isNotNull);
    });

    test('EncryptedLocalGoalRepository creates, updates, and pauses goals', () async {
      final store = await createTestDeviceStore();
      final repo = EncryptedLocalGoalRepository(store: store);
      final now = DateTime.now();

      // The repository starts empty; nothing is seeded by the app.
      expect((await repo.getGoals()).isEmpty, isTrue);

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
      expect((await repo.getGoals()).length, equals(1));

      // A user-created goal is not an AI-generated goal for today.
      expect(await repo.hasActiveAIGoalForToday(GoalType.dailyFocus), isFalse);

      // An AI-generated goal created today is detected as today's AI goal.
      await repo.saveGoal(sampleGoal(id: 'g-ai-today'));
      expect(await repo.hasActiveAIGoalForToday(GoalType.dailyFocus), isTrue);

      // Update progress to 20m -> should complete
      await repo.updateGoalProgress('g-custom-reading', 20);
      final completedGoal = await repo.getGoalById('g-custom-reading');
      expect(completedGoal?.isCompleted, isTrue);
      expect(completedGoal?.status, equals(GoalStatus.completed));

      // Pause goal
      await repo.updateGoalStatus('g-custom-reading', GoalStatus.paused);
      expect((await repo.getGoalById('g-custom-reading'))?.status, equals(GoalStatus.paused));
    });

    test('EncryptedLocalAchievementRepository updates badge progress and unlock timestamps', () async {
      final store = await createTestDeviceStore();
      final repo = EncryptedLocalAchievementRepository(store: store);

      // The repository starts empty: no badges are pre-seeded.
      expect((await repo.getAchievements()).isEmpty, isTrue);

      final balanceAch = ChildAchievement(
        id: 'ach-seven-day-balance',
        title: 'Seven Day Balance',
        description: 'Keep balanced device habits for 7 days.',
        icon: 'balance',
        type: AchievementType.sevenDayBalance,
        requirementValue: 7,
        requirementLabel: '7 balanced days',
      );

      await repo.saveAchievement(balanceAch);
      final saved = await repo.getAchievementById(balanceAch.id);
      expect(saved, isNotNull);
      expect(saved!.isUnlocked, isFalse);

      // Progress to 7 days
      await repo.updateAchievementProgress(balanceAch.id, 7, true);
      final unlocked = await repo.getAchievementById(balanceAch.id);
      expect(unlocked?.isUnlocked, isTrue);
      expect(unlocked?.unlockedAt, isNotNull);
      expect(unlocked?.progress, equals(1.0));
    });
  });
}
