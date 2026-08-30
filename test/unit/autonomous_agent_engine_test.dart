import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/agent_action_log_model.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/approved_report_model.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/data/models/notification_pref_model.dart';
import 'package:cleartime/data/models/privacy_setting_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/models/coaching_models.dart';
import 'package:cleartime/data/repositories/local_mission_repository.dart';
import 'package:cleartime/data/repositories/configuration_repository.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';
import 'package:cleartime/services/agent/autonomous_agent_engine.dart';

class MockMissionRepo implements LocalMissionRepository {
  final List<ChildMission> createdMissions = [];

  @override
  Future<List<ChildMission>> getMissions({String? childId}) async => createdMissions;
  @override
  Future<List<ChildMission>> getMissionsForParent({String? parentId, String? familyId}) async => createdMissions;
  @override
  Future<ChildMission?> getMissionById(String id) async => null;
  @override
  Future<ChildMission> createParentTask(ChildMission mission) async {
    createdMissions.add(mission);
    return mission;
  }
  @override
  Future<void> saveMission(ChildMission mission) async {
    createdMissions.add(mission);
  }
  @override
  Future<void> deleteMission(String id) async {
    createdMissions.removeWhere((m) => m.id == id);
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
      id: 'ai-mission-${createdMissions.length + 1}',
      title: title,
      description: description,
      source: MissionSource.localAi,
      type: MissionType.localAi,
      targetMinutes: targetMinutes,
      status: MissionStatus.assigned,
      dueDate: dueDate,
      createdAt: DateTime.now(),
    );
    createdMissions.add(mission);
    return mission;
  }
}

class MockConfigRepo implements ConfigurationRepository {
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

class MockReportRepo implements ApprovedReportRepository {
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

void main() {
  group('AutonomousAgentEngine Unit Tests', () {
    late MockMissionRepo missionRepo;
    late MockConfigRepo configRepo;
    late MockReportRepo reportRepo;
    late AutonomousAgentEngine engine;

    setUp(() {
      missionRepo = MockMissionRepo();
      configRepo = MockConfigRepo();
      reportRepo = MockReportRepo();
      engine = AutonomousAgentEngine(
        missionRepo: missionRepo,
        configRepo: configRepo,
        reportRepo: reportRepo,
      );
    });

    tearDown(() {
      engine.dispose();
    });

    test('Agent initializes with 24/7 online status and initial audit logs', () {
      expect(engine.isRunning, isTrue);
      expect(engine.lastHeartbeat, isNotNull);
      expect(engine.logs, isNotEmpty);
      expect(engine.logs.any((l) => l.actionType == AgentActionType.systemHeartbeat), isTrue);
    });

    test('dispatchSmartActivity creates real offline mission and records audit log', () async {
      final mission = await engine.dispatchSmartActivity(
        familyId: 'fam-1',
        childId: 'child-1',
        childName: 'Leo',
        activityTitle: 'Nature Trail Bike Ride',
        description: 'Take a 30m bike sprint outdoors.',
        durationMinutes: 30,
        category: 'Physical',
      );

      expect(mission.title, equals('Nature Trail Bike Ride'));
      expect(mission.targetMinutes, equals(30));
      expect(missionRepo.createdMissions.length, equals(1));

      final latestLog = engine.logs.first;
      expect(latestLog.actionType, equals(AgentActionType.activityDispatch));
      expect(latestLog.status, equals(AgentActionStatus.success));
      expect(latestLog.targetChildName, equals('Leo'));
      expect(latestLog.description, contains('Nature Trail Bike Ride'));
    });

    test('claimDailyAiQuest dynamically generates and persists daily quest', () async {
      final mission = await engine.claimDailyAiQuest(
        familyId: 'fam-1',
        childId: 'child-2',
        childName: 'Maya',
      );

      expect(mission.title, isNotEmpty);
      expect(mission.targetMinutes, isPositive);
      expect(missionRepo.createdMissions.length, equals(1));

      final latestLog = engine.logs.first;
      expect(latestLog.actionType, equals(AgentActionType.activityDispatch));
      expect(latestLog.targetChildName, equals('Maya'));
    });

    test('enforceDowntimeAlert logs downtime enforcement action', () async {
      await engine.enforceDowntimeAlert(
        familyId: 'fam-1',
        childId: 'child-1',
        childName: 'Leo',
      );

      final latestLog = engine.logs.first;
      expect(latestLog.actionType, equals(AgentActionType.downtimeEnforcement));
      expect(latestLog.status, equals(AgentActionStatus.success));
    });

    test('synthesizeWeeklyDeltaReport logs synthesis audit record', () async {
      final result = await engine.synthesizeWeeklyDeltaReport(
        familyId: 'fam-1',
        childId: 'child-1',
        childName: 'Leo',
      );

      expect(result, isNotEmpty);
      final latestLog = engine.logs.first;
      expect(latestLog.actionType, equals(AgentActionType.reportSynthesis));
      expect(latestLog.status, equals(AgentActionStatus.success));
    });
  });
}
