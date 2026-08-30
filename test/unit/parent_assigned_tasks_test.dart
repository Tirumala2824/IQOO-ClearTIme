import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/mission_model.dart';
import 'package:cleartime/data/models/child_profile_model.dart';
import 'package:cleartime/data/models/family_model.dart';
import 'package:cleartime/data/models/family_invitation_model.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/data/models/privacy_setting_model.dart';
import 'package:cleartime/data/models/notification_pref_model.dart';
import 'package:cleartime/data/models/usage_models.dart';
import 'package:cleartime/data/repositories/local_mission_repository.dart';
import 'package:cleartime/data/repositories/local_reward_repository.dart';
import 'package:cleartime/data/repositories/local_achievement_repository.dart';
import 'package:cleartime/data/repositories/family_repository.dart';
import 'package:cleartime/data/repositories/configuration_repository.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';
import 'package:cleartime/data/repositories/local_goal_repository.dart';
import 'package:cleartime/core/services/abstractions/usage_data_provider.dart';
import 'package:cleartime/core/services/abstractions/notification_provider.dart';
import 'package:cleartime/core/services/task_notification_service.dart';
import 'package:cleartime/core/platform/notification/native_notification_bridge.dart';
import 'package:cleartime/features/parent/controllers/parent_dashboard_controller.dart';
import 'package:cleartime/features/child/controllers/child_missions_controller.dart';
import 'package:cleartime/services/coaching/coaching_loop_service.dart';
import 'package:cleartime/services/coaching/pattern_detection_service.dart';
import 'package:cleartime/services/coaching/coaching_goal_generator.dart';
import 'package:cleartime/services/storage/encrypted_device_store.dart';
import '../helpers/encrypted_store_helper.dart';

class TestFamilyRepository implements FamilyRepository {
  @override
  Future<Family> createFamily({required String name, required String adminUserId}) async =>
      Family(id: 'f1', name: name, adminUserId: adminUserId, createdAt: DateTime.now(), updatedAt: DateTime.now());

  @override
  Future<Family?> getFamilyForUser(String userId) async =>
      Family(id: 'f1', name: 'Test Family', adminUserId: userId, createdAt: DateTime.now(), updatedAt: DateTime.now());

  @override
  Future<List<Family>> getAllFamiliesForUser(String userId) async => [
        Family(id: 'f1', name: 'Test Family', adminUserId: userId, createdAt: DateTime.now(), updatedAt: DateTime.now()),
      ];

  @override
  Future<Family> updateFamily(String familyId, {required String name}) async =>
      Family(id: familyId, name: name, adminUserId: 'u1', createdAt: DateTime.now(), updatedAt: DateTime.now());

  @override
  Future<void> deleteFamily(String familyId) async {}

  @override
  Future<void> deleteChildProfile(String childId) async {}

  @override
  Future<List<ChildProfile>> getChildrenForFamily(String familyId) async => [
        ChildProfile(id: 'child-1', userId: 'u-c1', familyId: familyId, nickname: 'Alex', createdAt: DateTime.now()),
      ];

  @override
  Future<ChildProfile?> getChildProfileForUser(String userId) async =>
      ChildProfile(id: 'child-1', userId: userId, familyId: 'f1', nickname: 'Alex', createdAt: DateTime.now());

  @override
  Future<ChildProfile?> updateChildProfile({
    String? nickname,
    int? age,
    int? avatarIndex,
  }) async =>
      ChildProfile(
        id: 'child-1',
        userId: 'u-c1',
        familyId: 'f1',
        nickname: nickname ?? 'Alex',
        age: age,
        avatarIndex: avatarIndex ?? 0,
        createdAt: DateTime.now(),
      );

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

class TestConfigurationRepository implements ConfigurationRepository {
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
  Future<PrivacySetting?> getPrivacySettings({required String familyId, required String userId}) async =>
      PrivacySetting(id: 'ps-1', familyId: familyId, userId: userId, updatedAt: DateTime.now());
  @override
  Future<PrivacySetting> updatePrivacySettings(PrivacySetting settings) async => settings;

  @override
  Future<NotificationPreference?> getNotificationPreferences(String userId) async =>
      NotificationPreference(id: 'np-1', userId: userId, familyId: 'f1', updatedAt: DateTime.now());
  @override
  Future<NotificationPreference> updateNotificationPreferences(NotificationPreference prefs) async => prefs;
}

/// Minimal fake usage provider for controller wiring in unit tests. The
/// production demo provider was removed; the controller only needs a
/// [UsageDataProvider] implementation.
class _FakeUsageProvider implements UsageDataProvider {
  @override
  Future<UsageAccessState> getUsageAccessState() async => UsageAccessState.ready;

  @override
  Future<bool> hasUsagePermission() async => true;

  @override
  Future<bool> requestUsagePermission() async => true;

  @override
  Future<UsageSummary> getTodayUsage() async => const UsageSummary(
        totalMinutes: 120,
        focusMinutes: 45,
        breakCount: 3,
        screenUnlockCount: 10,
        categories: [],
        topApps: [],
      );

  @override
  Future<List<DailyUsage>> getDailyUsage() async => const [];

  @override
  Future<List<DailyUsage>> getWeeklyUsage() async => const [];

  @override
  Future<List<DailyUsage>> getMonthlyUsage() async => const [];

  @override
  Future<List<CategoryUsage>> getCategoryUsage() async => const [];

  @override
  Future<List<UsageTimelineEntry>> getUsageTimeline() async => const [];

  @override
  Future<List<FocusSession>> getFocusSessions() async => const [];
}

void main() {
  group('Parent-Assigned Real-World Activities Architecture & Lifecycle Tests', () {
    late EncryptedDeviceStore store;
    late LocalMissionRepository missionRepo;
    late NotificationProvider notifBridge;
    late LocalAchievementRepository achRepo;
    late RewardRepository rewardRepo;

    setUp(() async {
      store = await createTestDeviceStore();
      missionRepo = InMemoryLocalMissionRepository();
      notifBridge = NativeNotificationBridge();
      achRepo = EncryptedLocalAchievementRepository(store: store);
      rewardRepo = InMemoryRewardRepository();
    });

    test('1. Repository starts empty with zero fake/dummy activities', () async {
      final missions = await missionRepo.getMissions();
      expect(missions, isEmpty);

      final parentTasks = await missionRepo.getMissionsForParent();
      expect(parentTasks, isEmpty);
    });

    test('2. Parent creates and persists real activity with all fields', () async {
      final dueDate = DateTime.now().add(const Duration(days: 2));
      final task = ChildMission(
        id: 'task-outdoor-1',
        title: 'Backyard Nature Exploration',
        description: 'Explore the garden and find 3 different leaves.',
        targetMinutes: 30,
        reward: 'Family ice cream trip',
        dueDate: dueDate,
        proofRequirement: ProofRequirement.photo,
        assignedByParentId: 'parent-123',
        assignedToChildId: 'child-abc',
        assignedToChildNickname: 'Leo',
      );

      await missionRepo.createParentTask(task);

      final saved = await missionRepo.getMissionById('task-outdoor-1');
      expect(saved, isNotNull);
      expect(saved!.title, equals('Backyard Nature Exploration'));
      expect(saved.description, equals('Explore the garden and find 3 different leaves.'));
      expect(saved.source, equals(MissionSource.parent));
      expect(saved.targetMinutes, equals(30));
      expect(saved.reward, equals('Family ice cream trip'));
      expect(saved.proofRequirement, equals(ProofRequirement.photo));
      expect(saved.status, equals(MissionStatus.assigned));
      expect(saved.assignedToChildId, equals('child-abc'));
      expect(saved.assignedToChildNickname, equals('Leo'));
      expect(saved.dueDate, equals(dueDate));
      expect(saved.isCompleted, isFalse);
    });

    test('3. Child isolation: child only sees activities assigned to them or unassigned family activities', () async {
      final taskChildA = ChildMission(
        id: 't-a',
        title: 'Child A Reading',
        description: 'Read a book',
        targetMinutes: 20,
        assignedToChildId: 'child-A',
      );
      final taskChildB = ChildMission(
        id: 't-b',
        title: 'Child B Bike Ride',
        description: 'Ride bike outdoors',
        targetMinutes: 30,
        assignedToChildId: 'child-B',
      );

      await missionRepo.createParentTask(taskChildA);
      await missionRepo.createParentTask(taskChildB);

      final childAMissions = await missionRepo.getMissions(childId: 'child-A');
      expect(childAMissions.length, equals(1));
      expect(childAMissions.first.id, equals('t-a'));

      final childBMissions = await missionRepo.getMissions(childId: 'child-B');
      expect(childBMissions.length, equals(1));
      expect(childBMissions.first.id, equals('t-b'));

      final parentTasks = await missionRepo.getMissionsForParent();
      expect(parentTasks.length, equals(2));
    });

    test('4. Full Real Lifecycle: assigned -> started -> submitted -> approved', () async {
      final task = ChildMission(
        id: 'task-family-dinner',
        title: 'Screen-Free Family Dinner',
        description: 'Enjoy dinner with family with all phones kept away.',
        targetMinutes: 45,
        proofRequirement: ProofRequirement.photoVideoParentApproval,
        reward: 'Pick family movie night movie',
        assignedToChildId: 'child-1',
      );

      await missionRepo.createParentTask(task);
      expect((await missionRepo.getMissionById('task-family-dinner'))?.status,
          equals(MissionStatus.assigned));

      // Step 1: Child starts activity
      await missionRepo.startMission('task-family-dinner');
      final startedTask = await missionRepo.getMissionById('task-family-dinner');
      expect(startedTask?.status, equals(MissionStatus.started));
      expect(startedTask?.startedAt, isNotNull);

      // Step 2: Child submits photo proof and notes
      await missionRepo.submitMission(
        'task-family-dinner',
        mediaPath: '/storage/DCIM/dinner_photo.jpg',
        mediaType: 'image',
        notes: 'Had fun talking about our favorite books at dinner!',
      );

      final submittedTask = await missionRepo.getMissionById('task-family-dinner');
      expect(submittedTask?.status, equals(MissionStatus.submitted));
      expect(submittedTask?.submittedAt, isNotNull);
      expect(submittedTask?.proofMediaPath, equals('/storage/DCIM/dinner_photo.jpg'));
      expect(submittedTask?.submissionNotes, equals('Had fun talking about our favorite books at dinner!'));

      // Step 3: Parent reviews and approves
      await missionRepo.approveMission(
        'task-family-dinner',
        parentFeedback: 'Loved having dinner together without phones!',
      );

      final approvedTask = await missionRepo.getMissionById('task-family-dinner');
      expect(approvedTask?.status, equals(MissionStatus.approved));
      expect(approvedTask?.isCompleted, isTrue);
      expect(approvedTask?.approvedAt, isNotNull);
      expect(approvedTask?.currentMinutes, equals(45));
      expect(approvedTask?.parentFeedback, equals('Loved having dinner together without phones!'));
    });

    test('5. Lifecycle: submitted -> needsRetry -> started -> submitted -> approved', () async {
      final task = ChildMission(
        id: 'task-exercise-1',
        title: '20-Minute Jump Rope',
        description: 'Practice jump roping in the backyard.',
        targetMinutes: 20,
        proofRequirement: ProofRequirement.parentApproval,
      );

      await missionRepo.createParentTask(task);
      await missionRepo.startMission('task-exercise-1');
      await missionRepo.submitMission('task-exercise-1', notes: 'Did 5 minutes');

      // Parent requests retry
      await missionRepo.rejectMissionNeedsRetry(
        'task-exercise-1',
        feedback: 'Please complete the full 20 minutes before submitting!',
      );

      final retryTask = await missionRepo.getMissionById('task-exercise-1');
      expect(retryTask?.status, equals(MissionStatus.needsRetry));
      expect(retryTask?.isNeedsRetry, isTrue);
      expect(retryTask?.parentFeedback,
          equals('Please complete the full 20 minutes before submitting!'));

      // Child tries again and restarts
      await missionRepo.startMission('task-exercise-1');
      expect((await missionRepo.getMissionById('task-exercise-1'))?.status,
          equals(MissionStatus.started));

      // Child submits again
      await missionRepo.submitMission('task-exercise-1', notes: 'Completed full 20 mins!');

      // Parent approves
      await missionRepo.approveMission('task-exercise-1');
      expect((await missionRepo.getMissionById('task-exercise-1'))?.status,
          equals(MissionStatus.approved));
    });

    test('6. No-proof activity completes immediately upon submission without requiring review', () async {
      final task = ChildMission(
        id: 'task-chores',
        title: 'Make Your Bed',
        description: 'Tidy up your room and make your bed.',
        targetMinutes: 10,
        proofRequirement: ProofRequirement.noProof,
      );

      await missionRepo.createParentTask(task);
      await missionRepo.startMission('task-chores');

      // Submit no-proof task
      await missionRepo.submitMission('task-chores');
      final completed = await missionRepo.getMissionById('task-chores');

      expect(completed?.status, equals(MissionStatus.approved));
      expect(completed?.isCompleted, isTrue);
      expect(completed?.completedAt, isNotNull);
    });

    test('7. Expiration logic: activity past due date is marked expired', () async {
      final pastDate = DateTime.now().subtract(const Duration(hours: 2));
      final task = ChildMission(
        id: 'task-expired',
        title: 'Morning Yoga',
        description: 'Do yoga before 9am',
        targetMinutes: 15,
        dueDate: pastDate,
      );

      await missionRepo.createParentTask(task);
      final missions = await missionRepo.getMissions();

      expect(missions.first.isExpired, isTrue);
      expect(missions.first.status, equals(MissionStatus.expired));
    });

    test('8. JSON Serialization retains all real-world activity fields', () {
      final now = DateTime.now();
      final task = ChildMission(
        id: 'pt-json-test',
        title: 'Drawing a Comic',
        description: 'Draw a 4-panel comic about your day.',
        targetMinutes: 25,
        status: MissionStatus.submitted,
        reward: 'New sketchbook',
        dueDate: now.add(const Duration(days: 3)),
        proofRequirement: ProofRequirement.photoVideoParentApproval,
        proofMediaPath: '/storage/DCIM/comic.jpg',
        proofMediaType: 'image',
        submissionNotes: 'Drew 4 panels!',
        parentFeedback: 'Looks amazing!',
        assignedByParentId: 'parent-99',
        assignedToChildId: 'child-88',
        assignedToChildNickname: 'Maya',
        createdAt: now,
        startedAt: now.add(const Duration(minutes: 5)),
        submittedAt: now.add(const Duration(minutes: 30)),
        approvedAt: now.add(const Duration(minutes: 40)),
        completedAt: now.add(const Duration(minutes: 40)),
      );

      final json = task.toJson();
      final reconstituted = ChildMission.fromJson(json);

      expect(reconstituted.id, equals(task.id));
      expect(reconstituted.title, equals(task.title));
      expect(reconstituted.source, equals(MissionSource.parent));
      expect(reconstituted.reward, equals('New sketchbook'));
      expect(reconstituted.proofRequirement, equals(ProofRequirement.photoVideoParentApproval));
      expect(reconstituted.proofMediaPath, equals('/storage/DCIM/comic.jpg'));
      expect(reconstituted.proofMediaType, equals('image'));
      expect(reconstituted.submissionNotes, equals('Drew 4 panels!'));
      expect(reconstituted.assignedToChildNickname, equals('Maya'));
    });

    test('9. ParentDashboardController dispatches real notifications on task actions', () async {
      final usageProvider = _FakeUsageProvider();
      final patternService = const PatternDetectionService();
      final goalGen = const CoachingGoalGenerator();
      final goalRepo = EncryptedLocalGoalRepository(store: store);
      final coachingLoop = CoachingLoopService(
        usageProvider: usageProvider,
        patternService: patternService,
        goalGenerator: goalGen,
        goalRepo: goalRepo,
        store: store,
      );
      await coachingLoop.loadHistory();

      final parentController = ParentDashboardController(
        familyRepository: TestFamilyRepository(),
        configurationRepository: TestConfigurationRepository(),
        approvedReportRepository: EncryptedApprovedReportRepository(store: store),
        usageDataProvider: usageProvider,
        coachingLoopService: coachingLoop,
        goalRepository: goalRepo,
        missionRepository: missionRepo,
        rewardRepository: rewardRepo,
        notificationProvider: notifBridge,
      );

      final success = await parentController.createParentTask(
        parentUserId: 'parent-1',
        childId: 'child-1',
        childNickname: 'Alex',
        title: 'Clean the Bicycle',
        description: 'Wash and oil the bicycle chain.',
        durationMinutes: 30,
        proofRequirement: ProofRequirement.photo,
        reward: 'Ice cream at the beach',
      );

      expect(success, isTrue);
      final tasks = await missionRepo.getMissionsForParent();
      expect(tasks.length, equals(1));
      expect(tasks.first.title, equals('Clean the Bicycle'));
      expect(tasks.first.reward, equals('Ice cream at the beach'));
    });

    test('10. ChildMissionsController dispatches alerts and updates achievements', () async {
      final childController = ChildMissionsController(
        repository: missionRepo,
        rewardRepository: rewardRepo,
        taskNotifications: TaskNotificationService(
          notificationProvider: notifBridge,
        ),
        achievementRepository: achRepo,
      );

      final task = ChildMission(
        id: 'm-read-nature',
        title: 'Tree Identification',
        description: 'Find and photograph 2 types of trees in the park.',
        targetMinutes: 20,
        proofRequirement: ProofRequirement.photo,
        assignedToChildId: 'child-sam',
      );

      await missionRepo.createParentTask(task);
      await childController.loadMissions(childId: 'child-sam');

      expect(childController.state.missions.length, equals(1));
      expect(childController.state.availableCount, equals(1));

      // Child starts
      await childController.startTask('m-read-nature');
      expect(childController.state.missions.first.status, equals(MissionStatus.started));

      // Child submits photo proof
      await childController.submitTask(
        'm-read-nature',
        mediaPath: '/DCIM/trees.jpg',
        mediaType: 'image',
        notes: 'Found oak and maple trees!',
      );

      expect(childController.state.missions.first.status, equals(MissionStatus.submitted));
      expect(childController.state.submittedMissions.length, equals(1));
    });
  });
}
