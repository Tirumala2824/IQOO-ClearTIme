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
import '../../../core/services/abstractions/usage_data_provider.dart';
import '../../../core/services/abstractions/notification_provider.dart';
import '../../../services/coaching/coaching_loop_service.dart';

class ParentDashboardState {
  final Family? family;
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
  final bool isLoading;
  final String? errorMessage;

  const ParentDashboardState({
    this.family,
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
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ParentDashboardState(
      family: family ?? this.family,
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
  final NotificationProvider _notificationProvider;

  ParentDashboardController({
    required FamilyRepository familyRepository,
    required ConfigurationRepository configurationRepository,
    required ApprovedReportRepository approvedReportRepository,
    required UsageDataProvider usageDataProvider,
    required CoachingLoopService coachingLoopService,
    required LocalGoalRepository goalRepository,
    required LocalMissionRepository missionRepository,
    required NotificationProvider notificationProvider,
  })  : _familyRepository = familyRepository,
        _configurationRepository = configurationRepository,
        _approvedReportRepository = approvedReportRepository,
        _usageDataProvider = usageDataProvider,
        _coachingLoopService = coachingLoopService,
        _goalRepository = goalRepository,
        _missionRepository = missionRepository,
        _notificationProvider = notificationProvider,
        super(const ParentDashboardState());

  Future<void> loadDashboard(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final family = await _familyRepository.getFamilyForUser(userId);
      if (family == null) {
        state = state.copyWith(isLoading: false, family: null, children: []);
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
      final todayUsage = await _usageDataProvider.getTodayUsage();
      final latestSession = _coachingLoopService.getTodaySession();
      final history = _coachingLoopService.getCoachingHistory();
      final goals = await _goalRepository.getGoals();
      final tasks = await _missionRepository.getMissionsForParent(parentId: userId);

      for (final child in children) {
        usageMap[child.id] = todayUsage;
        sessionMap[child.id] = latestSession;
      }

      // If no approved reports yet in memory, create reports based on usage
      if (allReports.isEmpty && children.isNotEmpty) {
        final now = DateTime.now();
        for (final child in children) {
          final defaultReport = ApprovedReport(
            id: 'rep-init-${child.id}',
            childId: child.id,
            childNickname: child.nickname,
            familyId: family.id,
            period: ReportPeriod.weekly,
            periodStart: now.subtract(const Duration(days: 7)),
            periodEnd: now,
            facts: ReportFacts(
              totalScreenMinutes: todayUsage.totalMinutes * 7,
              focusMinutes: todayUsage.focusMinutes * 7,
              breakCount: todayUsage.breakCount * 7,
              goalsCompletedCount: 4,
              goalsTotalCount: 5,
              changePercentage: todayUsage.changePercentageFromYesterday,
            ),
            summaryText:
                'Healthy screen-time balance with ${todayUsage.focusMinutes}m daily focus average and active coaching progression.',
            createdAt: now,
          );
          await _approvedReportRepository.saveApprovedReport(defaultReport);
          allReports.add(defaultReport);
        }
      }

      state = state.copyWith(
        family: family,
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
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createParentTask({
    required String parentUserId,
    required String childId,
    required String childNickname,
    required String title,
    required String description,
    required String category,
    required int durationMinutes,
    DateTime? dueDate,
    required ProofRequirement proofRequirement,
    String? reward,
    int points = 50,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final task = ChildMission(
        id: 'pt-${const Uuid().v4()}',
        title: title.trim(),
        description: description.trim(),
        category: category,
        type: MissionType.parentAssigned,
        targetMinutes: durationMinutes,
        points: points,
        status: MissionStatus.assigned,
        reward: reward?.trim().isNotEmpty == true ? reward!.trim() : null,
        dueDate: dueDate,
        proofRequirement: proofRequirement,
        assignedByParentId: parentUserId,
        assignedToChildId: childId,
        assignedToChildNickname: childNickname,
        createdAt: DateTime.now(),
      );

      await _missionRepository.createParentTask(task);
      final updatedTasks = await _missionRepository.getMissionsForParent(
        parentId: parentUserId,
      );

      state = state.copyWith(
        parentTasks: updatedTasks,
        isLoading: false,
      );

      // Send gentle notification to the child
      await _notificationProvider.showChildWellbeingNotification(
        id: task.id.hashCode.abs(),
        title: 'New Offline Mission! 🎯',
        body: 'Your parent assigned: "$title"${reward != null ? " (Reward: $reward)" : ""}',
      );

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
      final updatedTasks = await _missionRepository.getMissionsForParent();
      state = state.copyWith(parentTasks: updatedTasks);

      if (task != null) {
        await _notificationProvider.showChildWellbeingNotification(
          id: taskId.hashCode.abs(),
          title: 'Mission Approved! 🌟🎉',
          body: 'Great job! "${task.title}" has been approved.${task.reward != null ? " Reward: ${task.reward}" : ""}',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> requestTaskRetry(String taskId, {required String feedback}) async {
    try {
      final task = await _missionRepository.getMissionById(taskId);
      await _missionRepository.rejectMissionNeedsRetry(
        taskId,
        feedback: feedback,
      );
      final updatedTasks = await _missionRepository.getMissionsForParent();
      state = state.copyWith(parentTasks: updatedTasks);

      if (task != null) {
        await _notificationProvider.showChildWellbeingNotification(
          id: taskId.hashCode.abs(),
          title: 'Mission Needs Another Try 💪',
          body: 'For "${task.title}": $feedback',
        );
      }
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteParentTask(String taskId) async {
    try {
      await _missionRepository.deleteMission(taskId);
      final updatedTasks = await _missionRepository.getMissionsForParent();
      state = state.copyWith(parentTasks: updatedTasks);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> refreshParentTasks() async {
    try {
      final updatedTasks = await _missionRepository.getMissionsForParent();
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
  final notifProvider = ref.watch(notificationProvider);

  return ParentDashboardController(
    familyRepository: familyRepo,
    configurationRepository: configRepo,
    approvedReportRepository: reportRepo,
    usageDataProvider: usageProvider,
    coachingLoopService: coachingLoop,
    goalRepository: goalRepo,
    missionRepository: missionRepo,
    notificationProvider: notifProvider,
  );
});
