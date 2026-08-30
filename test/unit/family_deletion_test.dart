import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/family_model.dart';
import 'package:cleartime/data/models/child_profile_model.dart';
import 'package:cleartime/data/repositories/family_repository.dart';
import 'package:cleartime/features/parent/controllers/parent_dashboard_controller.dart';
import 'package:cleartime/data/repositories/configuration_repository.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';
import 'package:cleartime/data/repositories/local_goal_repository.dart';
import 'package:cleartime/data/repositories/local_mission_repository.dart';
import 'package:cleartime/data/repositories/local_reward_repository.dart';
import 'package:cleartime/core/services/abstractions/usage_data_provider.dart';
import 'package:cleartime/core/services/abstractions/notification_provider.dart';
import 'package:cleartime/services/coaching/coaching_loop_service.dart';
import 'package:cleartime/data/models/family_invitation_model.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/data/models/notification_pref_model.dart';
import 'package:cleartime/data/models/privacy_setting_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/reward_model.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/goal_model.dart';
import 'package:cleartime/data/models/coaching_models.dart';
import 'package:cleartime/services/coaching/pattern_detection_service.dart';
import 'package:cleartime/services/coaching/coaching_goal_generator.dart';

class InMemoryFamilyRepository implements FamilyRepository {
  final Map<String, Family> families = {};
  final Map<String, List<ChildProfile>> children = {};

  @override
  Future<Family> createFamily({required String name, required String adminUserId}) async {
    final fam = Family(
      id: 'fam-${families.length + 1}',
      name: name,
      adminUserId: adminUserId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    families[fam.id] = fam;
    children[fam.id] = [];
    return fam;
  }

  @override
  Future<Family?> getFamilyForUser(String userId) async {
    return families.values
            .where((f) => f.adminUserId == userId)
            .firstOrNull ??
        families.values.firstOrNull;
  }

  @override
  Future<List<Family>> getAllFamiliesForUser(String userId) async {
    return families.values.where((f) => f.adminUserId == userId).toList();
  }

  @override
  Future<Family> updateFamily(String familyId, {required String name}) async {
    final existing = families[familyId]!;
    final updated = existing.copyWith(name: name);
    families[familyId] = updated;
    return updated;
  }

  @override
  Future<void> deleteFamily(String familyId) async {
    families.remove(familyId);
    children.remove(familyId);
  }

  @override
  Future<void> deleteChildProfile(String childId) async {
    for (final famId in children.keys) {
      children[famId]?.removeWhere((c) => c.id == childId);
    }
  }

  @override
  Future<List<ChildProfile>> getChildrenForFamily(String familyId) async {
    return children[familyId] ?? [];
  }

  @override
  Future<ChildProfile?> getChildProfileForUser(String userId) async => null;

  @override
  Future<ChildProfile?> updateChildProfile({String? nickname, int? age, int? avatarIndex}) async => null;

  @override
  Future<FamilyInvitation> generateInvitation({required String familyId, required String createdBy}) async =>
      throw UnimplementedError();

  @override
  Future<List<FamilyInvitation>> getActiveInvitations(String familyId) async => [];

  @override
  Future<void> revokeInvitation(String invitationId) async {}

  @override
  Future<ChildProfile> redeemInvitation({
    required String invitationCode,
    required String childUserId,
    required String nickname,
    int? age,
    int avatarIndex = 0,
  }) async =>
      throw UnimplementedError();
}

class FakeConfigRepo implements ConfigurationRepository {
  @override
  Future<List<ReportConfiguration>> getReportConfigurations(String familyId) async => [];
  @override
  Future<ReportConfiguration> createReportConfiguration(ReportConfiguration config) async => config;
  @override
  Future<ReportConfiguration> updateReportConfiguration(ReportConfiguration config) async => config;
  @override
  Future<void> deleteReportConfiguration(String id) async {}
  @override
  Future<List<TriggerConfiguration>> getTriggerConfigurations(String familyId) async => [];
  @override
  Future<TriggerConfiguration> createTriggerConfiguration(TriggerConfiguration config) async => config;
  @override
  Future<TriggerConfiguration> updateTriggerConfiguration(TriggerConfiguration config) async => config;
  @override
  Future<void> deleteTriggerConfiguration(String id) async {}
  @override
  Future<NotificationPreference?> getNotificationPreferences(String userId) async => null;
  @override
  Future<NotificationPreference> updateNotificationPreferences(NotificationPreference prefs) async => prefs;
  @override
  Future<PrivacySetting?> getPrivacySettings({required String familyId, required String userId}) async => null;
  @override
  Future<PrivacySetting> updatePrivacySettings(PrivacySetting settings) async => settings;
}

class FakeReportRepo implements ApprovedReportRepository {
  final List<ApprovedReport> reports = [];

  @override
  Future<List<ApprovedReport>> getApprovedReports(String childId) async => reports;
  @override
  Future<ApprovedReport?> getApprovedReport(String reportId) async => null;
  @override
  Future<List<ApprovedReport>> getReportHistory(String childId, {ReportPeriod? period}) async => reports;
  @override
  Future<void> saveApprovedReport(ApprovedReport report) async {
    reports.add(report);
  }
  @override
  Future<List<ApprovedReport>> getMultiChildApprovedReports(List<String> childIds) async => reports;
  @override
  Future<void> deleteApprovedReport(String reportId) async {}
  @override
  Future<void> clearLocalCache() async {
    reports.clear();
  }
}

class FakeMissionRepo implements LocalMissionRepository {
  final List<ChildMission> missions = [];

  @override
  Future<List<ChildMission>> getMissions({String? childId}) async => missions;
  @override
  Future<List<ChildMission>> getMissionsForParent({String? parentId, String? familyId}) async => missions;
  @override
  Future<ChildMission?> getMissionById(String id) async => null;
  @override
  Future<ChildMission> createParentTask(ChildMission mission) async {
    missions.add(mission);
    return mission;
  }
  @override
  Future<void> saveMission(ChildMission mission) async {
    missions.add(mission);
  }
  @override
  Future<void> deleteMission(String id) async {
    missions.removeWhere((m) => m.id == id);
  }
  @override
  Future<void> updateMissionProgress(String id, int minutes) async {}
  @override
  Future<void> completeMission(String id) async {}
  @override
  Future<void> startMission(String id, {String? childId}) async {}
  @override
  Future<void> submitMission(String id, {String? mediaPath, String? mediaType, String? notes, String? childId}) async {}
  @override
  Future<void> approveMission(String id, {String? parentFeedback}) async {}
  @override
  Future<void> rejectMissionNeedsRetry(String id, {String? feedback}) async {}
  @override
  Future<void> resetDailyMissions() async {}
  @override
  Future<void> checkAndExpireMissions() async {}
  @override
  Future<void> expireOverdueMissions() async {}
  @override
  Future<List<ChildMission>> generateDynamicMissions({required UsageSummary usage, required List<DetectedPattern> patterns}) async => [];
  @override
  Future<ChildMission> createLocalAiMission({
    required String title,
    String description = '',
    int targetMinutes = 30,
    DateTime? dueDate,
    String? childId,
    String? childNickname,
    String? familyId,
  }) async {
    final mission = ChildMission(
      id: 'ai-mission-${missions.length + 1}',
      title: title,
      description: description,
      source: MissionSource.localAi,
      type: MissionType.localAi,
      targetMinutes: targetMinutes,
      status: MissionStatus.assigned,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    missions.add(mission);
    return mission;
  }
}

class FakeRewardRepo implements RewardRepository {
  @override
  Future<Reward> createReward(Reward reward) async => reward;
  @override
  Future<Reward?> getRewardById(String id) async => null;
  @override
  Future<Reward?> getRewardForTask(String taskId) async => null;
  @override
  Future<List<Reward>> getRewardsForChild(String childId) async => [];
  @override
  Future<List<Reward>> getRewardsForParent(String parentId) async => [];
  @override
  Future<Reward> unlockReward(String rewardId) async => throw UnimplementedError();
  @override
  Future<Reward> redeemReward(String rewardId) async => throw UnimplementedError();
  @override
  Future<Reward> cancelReward(String rewardId, {required String actorUserId}) async => throw UnimplementedError();
}

class FakeGoalRepo implements LocalGoalRepository {
  final List<ChildGoal> goals = [];

  @override
  Future<List<ChildGoal>> getGoals() async => goals;
  @override
  Future<ChildGoal?> getGoalById(String id) async => null;
  @override
  Future<ChildGoal?> getActiveAIGoal() async => null;
  @override
  Future<bool> hasActiveAIGoalForToday(GoalType type) async => false;
  @override
  Future<List<ChildGoal>> getGoalHistory() async => goals;
  @override
  Future<void> saveGoal(ChildGoal goal) async {
    goals.add(goal);
  }
  @override
  Future<void> updateGoalProgress(String id, int progress) async {}
  @override
  Future<void> updateGoalStatus(String id, GoalStatus status) async {}
  @override
  Future<void> deleteGoal(String id) async {
    goals.removeWhere((g) => g.id == id);
  }
}

class FakeUsageProvider implements UsageDataProvider {
  @override
  Future<UsageAccessState> getUsageAccessState() async => UsageAccessState.unsupported;
  @override
  Future<bool> hasUsagePermission() async => false;
  @override
  Future<bool> requestUsagePermission() async => false;
  @override
  Future<UsageSummary> getTodayUsage() async => const UsageSummary(totalMinutes: 0, focusMinutes: 0, breakCount: 0);
  @override
  Future<List<DailyUsage>> getDailyUsage() async => [];
  @override
  Future<List<DailyUsage>> getWeeklyUsage() async => [];
  @override
  Future<List<DailyUsage>> getMonthlyUsage() async => [];
  @override
  Future<List<CategoryUsage>> getCategoryUsage() async => [];
  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async => [];
  @override
  Future<List<FocusSession>> getFocusSessions() async => [];
}

class FakeNotifProvider implements NotificationProvider {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? payload,
    NotificationType notificationType = NotificationType.push,
  }) async {}
  @override
  Future<void> showChildWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
  @override
  Future<void> showParentAlertNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {}
  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? channelId,
    String? payload,
  }) async {}
  @override
  Future<void> cancelNotification(int id) async {}
  @override
  Future<void> cancelAllNotifications() async {}
}

void main() {
  group('Family Group Deletion & State Clearing Tests', () {
    late InMemoryFamilyRepository familyRepo;
    late ParentDashboardController controller;

    setUp(() {
      familyRepo = InMemoryFamilyRepository();
      controller = ParentDashboardController(
        familyRepository: familyRepo,
        configurationRepository: FakeConfigRepo(),
        approvedReportRepository: FakeReportRepo(),
        usageDataProvider: FakeUsageProvider(),
        coachingLoopService: CoachingLoopService(
          usageProvider: FakeUsageProvider(),
          patternService: const PatternDetectionService(),
          goalGenerator: const CoachingGoalGenerator(),
          goalRepo: FakeGoalRepo(),
        ),
        goalRepository: FakeGoalRepo(),
        missionRepository: FakeMissionRepo(),
        rewardRepository: FakeRewardRepo(),
        notificationProvider: FakeNotifProvider(),
      );
    });

    test('Deleting current family resets state cleanly when no other families exist', () async {
      final fam = await familyRepo.createFamily(name: 'Solo Family', adminUserId: 'parent-1');
      await controller.loadDashboard('parent-1', forceFamily: fam);

      expect(controller.state.family?.id, equals(fam.id));
      expect(controller.state.allFamilies.length, equals(1));

      final deleted = await controller.deleteCurrentFamily(fam.id, 'parent-1');

      expect(deleted, isTrue);
      expect(controller.state.family, isNull);
      expect(controller.state.allFamilies, isEmpty);
      expect(controller.state.children, isEmpty);
    });

    test('Deleting active family automatically switches to remaining family', () async {
      final fam1 = await familyRepo.createFamily(name: 'Family One', adminUserId: 'parent-1');
      final fam2 = await familyRepo.createFamily(name: 'Family Two', adminUserId: 'parent-1');

      await controller.loadDashboard('parent-1', forceFamily: fam1);
      expect(controller.state.family?.id, equals(fam1.id));
      expect(controller.state.allFamilies.length, equals(2));

      final deleted = await controller.deleteCurrentFamily(fam1.id, 'parent-1');

      expect(deleted, isTrue);
      expect(controller.state.family?.id, equals(fam2.id));
      expect(controller.state.allFamilies.length, equals(1));
      expect(controller.state.allFamilies.first.name, equals('Family Two'));
    });
  });
}
