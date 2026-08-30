import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:uuid/uuid.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/family_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/report_config_model.dart';
import '../../../data/models/trigger_config_model.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../data/models/privacy_setting_model.dart';
import '../../../data/models/usage_models.dart';
import '../../../data/models/coaching_models.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/configuration_repository.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/repositories/approved_report_repository.dart';
import '../../../data/repositories/local_goal_repository.dart';
import '../../../data/repositories/local_mission_repository.dart';
import '../../../data/repositories/local_reward_repository.dart';
import '../../../core/services/abstractions/usage_data_provider.dart';
import '../../../core/services/abstractions/notification_provider.dart';
import '../../../core/services/task_notification_service.dart';
import '../../../data/models/reward_model.dart';
import '../../../services/coaching/coaching_loop_service.dart';
import '../../../services/realtime/mission_realtime_service.dart';

class ParentDashboardState {
  final Family? family;
  final List<Family> allFamilies;
  final List<ChildProfile> children;
  final List<ReportConfiguration> reports;
  final List<TriggerConfiguration> triggers;
  final List<ApprovedReport> approvedReports;
  final List<String> activeAlerts;
  final NotificationPreference? notificationPrefs;
  final PrivacySetting? privacySettings;
  final Map<String, UsageSummary> childUsageSummaries;
  final Map<String, CoachingSession?> childCoachingSessions;
  final CoachingHistory coachingHistory;
  final List<ChildGoal> childGoals;
  final List<ChildMission> parentTasks;
  final List<Reward> rewards;
  final bool isLoading;
  final String? errorMessage;

  const ParentDashboardState({
    this.family,
    this.allFamilies = const [],
    this.children = const [],
    this.reports = const [],
    this.triggers = const [],
    this.approvedReports = const [],
    this.activeAlerts = const [],
    this.notificationPrefs,
    this.privacySettings,
    this.childUsageSummaries = const {},
    this.childCoachingSessions = const {},
    this.coachingHistory = const CoachingHistory(),
    this.childGoals = const [],
    this.parentTasks = const [],
    this.rewards = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasFamily => family != null;
  bool get hasChildren => children.isNotEmpty;

  List<ChildMission> get activeParentTasks => parentTasks
      .where((t) =>
          t.status == MissionStatus.assigned ||
          t.status == MissionStatus.started ||
          t.status == MissionStatus.needsRetry)
      .toList();

  List<ChildMission> get pendingReviewTasks => parentTasks
      .where((t) => t.status == MissionStatus.submitted)
      .toList();

  List<ChildMission> get completedTasks => parentTasks
      .where((t) => t.status == MissionStatus.approved)
      .toList();

  ParentDashboardState copyWith({
    Family? family,
    List<Family>? allFamilies,
    List<ChildProfile>? children,
    List<ReportConfiguration>? reports,
    List<TriggerConfiguration>? triggers,
    List<ApprovedReport>? approvedReports,
    List<String>? activeAlerts,
    NotificationPreference? notificationPrefs,
    PrivacySetting? privacySettings,
    Map<String, UsageSummary>? childUsageSummaries,
    Map<String, CoachingSession?>? childCoachingSessions,
    CoachingHistory? coachingHistory,
    List<ChildGoal>? childGoals,
    List<ChildMission>? parentTasks,
    List<Reward>? rewards,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ParentDashboardState(
      family: family ?? this.family,
      allFamilies: allFamilies ?? this.allFamilies,
      children: children ?? this.children,
      reports: reports ?? this.reports,
      triggers: triggers ?? this.triggers,
      approvedReports: approvedReports ?? this.approvedReports,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      privacySettings: privacySettings ?? this.privacySettings,
      childUsageSummaries: childUsageSummaries ?? this.childUsageSummaries,
      childCoachingSessions:
          childCoachingSessions ?? this.childCoachingSessions,
      coachingHistory: coachingHistory ?? this.coachingHistory,
      childGoals: childGoals ?? this.childGoals,
      parentTasks: parentTasks ?? this.parentTasks,
      rewards: rewards ?? this.rewards,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ParentDashboardController extends StateNotifier<ParentDashboardState> {
  final FamilyRepository _familyRepository;
  final ConfigurationRepository _configurationRepository;
  final ApprovedReportRepository _approvedReportRepository;
  final UsageDataProvider _usageDataProvider;
  final CoachingLoopService _coachingLoopService;
  final LocalGoalRepository _goalRepository;
  final LocalMissionRepository _missionRepository;
  final RewardRepository _rewardRepository;
  final TaskNotificationService _taskNotifications;
  final MissionRealtimeService? _realtimeService;
  bool _realtimeSubscribed = false;

  ParentDashboardController({
    required FamilyRepository familyRepository,
    required ConfigurationRepository configurationRepository,
    required ApprovedReportRepository approvedReportRepository,
    required UsageDataProvider usageDataProvider,
    required CoachingLoopService coachingLoopService,
    required LocalGoalRepository goalRepository,
    required LocalMissionRepository missionRepository,
    required RewardRepository rewardRepository,
    required NotificationProvider notificationProvider,
    MissionRealtimeService? realtimeService,
  })  : _familyRepository = familyRepository,
        _configurationRepository = configurationRepository,
        _approvedReportRepository = approvedReportRepository,
        _usageDataProvider = usageDataProvider,
        _coachingLoopService = coachingLoopService,
        _goalRepository = goalRepository,
        _missionRepository = missionRepository,
        _rewardRepository = rewardRepository,
        _realtimeService = realtimeService,
        _taskNotifications = TaskNotificationService(
          notificationProvider: notificationProvider,
        ),
        super(const ParentDashboardState());

  Future<void> loadDashboard(String userId, {Family? forceFamily}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final allFamilies = await _familyRepository.getAllFamiliesForUser(userId);
      final family = forceFamily ??
          (state.family != null && allFamilies.any((f) => f.id == state.family!.id)
              ? allFamilies.firstWhere((f) => f.id == state.family!.id)
              : (allFamilies.isNotEmpty
                  ? allFamilies.first
                  : await _familyRepository.getFamilyForUser(userId)));

      if (family == null) {
        state = state.copyWith(
          isLoading: false,
          family: null,
          allFamilies: allFamilies,
          children: [],
        );
        return;
      }

      final children = await _familyRepository.getChildrenForFamily(family.id);
      final reports =
          await _configurationRepository.getReportConfigurations(family.id);
      final triggers =
          await _configurationRepository.getTriggerConfigurations(family.id);
      final notifs =
          await _configurationRepository.getNotificationPreferences(userId);
      final privacy = await _configurationRepository.getPrivacySettings(
        familyId: family.id,
        userId: userId,
      );

      // Load approved reports for all children
      final List<ApprovedReport> allReports = [];
      final List<String> alerts = [];

      for (final child in children) {
        final childReports =
            await _approvedReportRepository.getApprovedReports(child.id);
        allReports.addAll(childReports);
      }

      // Load live child usage and coaching loop status
      final Map<String, UsageSummary> usageMap = {};
      final Map<String, CoachingSession?> sessionMap = {};

      UsageSummary todayUsage = const UsageSummary(
        totalMinutes: 0,
        focusMinutes: 0,
        breakCount: 0,
      );
      try {
        todayUsage = await _usageDataProvider.getTodayUsage();
      } catch (_) {
        // Usage access is child-device specific; parent devices gracefully default to 0.
      }

      CoachingSession? latestSession;
      try {
        latestSession = _coachingLoopService.getTodaySession();
      } catch (_) {}

      CoachingHistory history = const CoachingHistory();
      try {
        history = _coachingLoopService.getCoachingHistory();
      } catch (_) {}

      final goals = await _goalRepository.getGoals();
      final tasks = await _missionRepository.getMissionsForParent(
        parentId: userId,
        familyId: family.id,
      );
      final rewards = await _rewardRepository.getRewardsForParent(userId);

      for (final child in children) {
        usageMap[child.id] = todayUsage;
        sessionMap[child.id] = latestSession;
      }

      state = state.copyWith(
        family: family,
        allFamilies: allFamilies,
        children: children,
        reports: reports,
        triggers: triggers,
        approvedReports: allReports,
        activeAlerts: alerts,
        notificationPrefs: notifs,
        privacySettings: privacy,
        childUsageSummaries: usageMap,
        childCoachingSessions: sessionMap,
        coachingHistory: history,
        childGoals: goals,
        parentTasks: tasks,
        rewards: rewards,
        isLoading: false,
      );

      _subscribeRealtime(family.id, userId);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> switchFamily(Family newFamily, String userId) async {
    await loadDashboard(userId, forceFamily: newFamily);
  }

  Future<bool> createNewFamily(String name, String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newFamily = await _familyRepository.createFamily(
        name: name.trim(),
        adminUserId: userId,
      );
      await loadDashboard(userId, forceFamily: newFamily);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> renameFamily(String familyId, String newName, String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final updated = await _familyRepository.updateFamily(familyId, name: newName);
      await loadDashboard(userId, forceFamily: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> deleteCurrentFamily(String familyId, String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _familyRepository.deleteFamily(familyId);
      await loadDashboard(userId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  /// Refreshes parent task state when the child starts or submits an
  /// activity anywhere, so cross-device visibility is immediate.
  void _subscribeRealtime(String familyId, String userId) {
    final realtime = _realtimeService;
    if (realtime == null || _realtimeSubscribed) return;
    _realtimeSubscribed = true;

    realtime.subscribeToFamilyMissionChanges(
      familyId: familyId,
      onRefresh: () {
        if (!state.isLoading) loadDashboard(userId);
      },
    );
  }

  Future<bool> createParentTask({
    required String parentUserId,
    required String childId,
    required String childNickname,
    required String title,
    required String description,
    required int durationMinutes,
    DateTime? dueDate,
    required ProofRequirement proofRequirement,
    String? reward,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final task = ChildMission(
        id: 'pt-${const Uuid().v4()}', // placeholder; canonical id comes back
        title: title.trim(),
        description: description.trim(),
        type: MissionType.parentAssigned,
        targetMinutes: durationMinutes,
        status: MissionStatus.assigned,
        reward: reward?.trim().isNotEmpty == true ? reward!.trim() : null,
        dueDate: dueDate,
        proofRequirement: proofRequirement,
        assignedByParentId: parentUserId,
        assignedToChildId: childId,
        assignedToChildNickname: childNickname,
        createdAt: DateTime.now(),
      );

      // The RPC returns the canonical database mission; use it as the
      // single source of truth for the id on both reward and notification.
      final createdTask = await _missionRepository.createParentTask(task);

      // Persist a real reward in [locked] state when the parent configured
      // one. It is never unlocked at creation time; unlocking is a business
      // event that happens only on approval (or approved auto-completion).
      if (reward != null && reward.trim().isNotEmpty) {
        await _rewardRepository.createReward(Reward(
          id: 'rw-${createdTask.id}',
          parentId: parentUserId,
          childId: childId,
          taskId: createdTask.id,
          title: reward.trim(),
        ));
      }

      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: parentUserId,
        familyId: state.family?.id,
      );
      final updatedRewards = await _rewardRepository.getRewardsForParent(
        parentUserId,
      );

      state = state.copyWith(
        parentTasks: updatedTasks,
        rewards: updatedRewards,
        isLoading: false,
      );

      // [NEW_TASK] is generated only after the task assignment succeeded.
      // If persistence had failed above, we would never reach this line.
      await _taskNotifications.notifyNewTask(createdTask);

      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> approveTask(String taskId, {String? feedback}) async {
    try {
      final task = await _missionRepository.getMissionById(taskId);
      await _missionRepository.approveMission(taskId, parentFeedback: feedback);

      // The unlock condition (parent approval of a submitted task) is now
      // satisfied: transition the real reward [locked] -> [unlocked].
      Reward? unlockedReward;
      if (task != null) {
        final reward = await _rewardRepository.getRewardForTask(taskId);
        if (reward != null && reward.isLocked) {
          unlockedReward = await _rewardRepository.unlockReward(reward.id);
        }
      }

      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: task?.assignedByParentId ?? state.family?.adminUserId,
        familyId: state.family?.id,
      );
      final parentUid = task?.assignedByParentId ?? state.family?.adminUserId;
      final updatedRewards = parentUid == null
          ? state.rewards
          : await _rewardRepository.getRewardsForParent(parentUid);
      state = state.copyWith(parentTasks: updatedTasks, rewards: updatedRewards);

      if (task != null) {
        await _taskNotifications.notifyTaskApproved(
          task: task,
          unlockedReward: unlockedReward,
        );
        if (unlockedReward != null) {
          await _taskNotifications.notifyRewardUnlocked(
            reward: unlockedReward,
            childNickname: task.assignedToChildNickname ?? 'Hey',
          );
        }
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  /// Parent requests another attempt: [submitted] -> [needs_retry].
  /// A reason is optional; only a parent-provided reason is stored.
  Future<void> requestTaskRetry(String taskId, {String? feedback}) async {
    try {
      final task = await _missionRepository.getMissionById(taskId);
      await _missionRepository.rejectMissionNeedsRetry(
        taskId,
        feedback: feedback,
      );
      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: task?.assignedByParentId ?? state.family?.adminUserId,
        familyId: state.family?.id,
      );
      state = state.copyWith(parentTasks: updatedTasks);

      if (task != null) {
        await _taskNotifications.notifyTaskNeedsRetry(
          task: task,
          parentReason: feedback,
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> updateParentTask(ChildMission updatedMission) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _missionRepository.saveMission(updatedMission);
      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: state.family?.adminUserId,
        familyId: state.family?.id,
      );
      state = state.copyWith(parentTasks: updatedTasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteParentTask(String taskId) async {
    try {
      await _missionRepository.deleteMission(taskId);
      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: state.family?.adminUserId,
        familyId: state.family?.id,
      );
      state = state.copyWith(parentTasks: updatedTasks);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> refreshParentTasks() async {
    try {
      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: state.family?.adminUserId,
        familyId: state.family?.id,
      );
      state = state.copyWith(parentTasks: updatedTasks);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<bool> createFamily({
    required String name,
    required String parentUserId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _familyRepository.createFamily(
        name: name,
        adminUserId: parentUserId,
      );
      await loadDashboard(parentUserId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> addReport(ReportConfiguration config) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created =
          await _configurationRepository.createReportConfiguration(config);
      state = state.copyWith(
        reports: [...state.reports, created],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleReport(ReportConfiguration config, bool enabled) async {
    try {
      final updated = config.copyWith(isEnabled: enabled);
      await _configurationRepository.updateReportConfiguration(updated);
      final list =
          state.reports.map((r) => r.id == config.id ? updated : r).toList();
      state = state.copyWith(reports: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _configurationRepository.deleteReportConfiguration(id);
      final list = state.reports.where((r) => r.id != id).toList();
      state = state.copyWith(reports: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> addTrigger(TriggerConfiguration config) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created =
          await _configurationRepository.createTriggerConfiguration(config);
      state = state.copyWith(
        triggers: [...state.triggers, created],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleTrigger(TriggerConfiguration config, bool active) async {
    try {
      final updated = config.copyWith(enabled: active);
      await _configurationRepository.updateTriggerConfiguration(updated);
      final List<TriggerConfiguration> list =
          state.triggers.map((t) => t.id == config.id ? updated : t).toList();
      state = state.copyWith(triggers: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteTrigger(String id) async {
    try {
      await _configurationRepository.deleteTriggerConfiguration(id);
      final list = state.triggers.where((t) => t.id != id).toList();
      state = state.copyWith(triggers: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> saveNotificationPreferences(NotificationPreference prefs) async {
    try {
      final updated =
          await _configurationRepository.updateNotificationPreferences(prefs);
      state = state.copyWith(notificationPrefs: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> savePrivacySettings(PrivacySetting settings) async {
    try {
      final updated =
          await _configurationRepository.updatePrivacySettings(settings);
      state = state.copyWith(privacySettings: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final parentDashboardControllerProvider =
    StateNotifierProvider<ParentDashboardController, ParentDashboardState>(
        (ref) {
  final familyRepo = ref.watch(familyRepositoryProvider);
  final configRepo = ref.watch(configurationRepositoryProvider);
  final reportRepo = ref.watch(approvedReportRepositoryProvider);
  final usageProvider = ref.watch(usageDataProvider);
  final coachingLoop = ref.watch(coachingLoopServiceProvider);
  final goalRepo = ref.watch(localGoalRepositoryProvider);
  final missionRepo = ref.watch(localMissionRepositoryProvider);
  final rewardRepo = ref.watch(rewardRepositoryProvider);
  final notifProvider = ref.watch(notificationProvider);
  final realtimeService = ref.watch(missionRealtimeServiceProvider);

  return ParentDashboardController(
    familyRepository: familyRepo,
    configurationRepository: configRepo,
    approvedReportRepository: reportRepo,
    usageDataProvider: usageProvider,
    coachingLoopService: coachingLoop,
    goalRepository: goalRepo,
    missionRepository: missionRepo,
    rewardRepository: rewardRepo,
    notificationProvider: notifProvider,
    realtimeService: realtimeService,
  );
});
