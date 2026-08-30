import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../../core/providers/providers.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/family_model.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/usage_models.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/reflection_model.dart';
import '../../../data/models/coaching_models.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/local_mission_repository.dart';
import '../../../data/repositories/local_goal_repository.dart';
import '../../../data/repositories/local_reflection_repository.dart';
import '../../../core/services/abstractions/usage_data_provider.dart';
import '../../../core/services/abstractions/notification_provider.dart';
import '../../../services/coaching/coaching_loop_service.dart';
import '../../../services/llm/local_ai_activity_service.dart';
import '../../../services/realtime/mission_realtime_service.dart';
import '../../../services/analytics/report_request_service.dart';
import '../../../services/analytics/report_scheduler_service.dart';

class ChildDashboardState {
  final ChildProfile? profile;
  final Family? family;
  final UsageSummary usageSummary;
  final UsageAccessState usageAccessState;
  final List<ChildMission> missions;
  final List<ChildGoal> goals;
  final DailyReflection? todayReflection;
  final CoachingSession? coachingSession;
  final List<DetectedPattern> detectedPatterns;
  final ChildGoal? activeAIGoal;
  final CoachingHistory coachingHistory;
  final bool isCoachingLoopRunning;
  final CoachingSessionStatus? coachingLoopStep;
  final bool isLoading;
  final String? errorMessage;

  const ChildDashboardState({
    this.profile,
    this.family,
    this.usageSummary = const UsageSummary(
      totalMinutes: 0,
      focusMinutes: 0,
      breakCount: 0,
      screenUnlockCount: 0,
      categories: [],
      topApps: [],
    ),
    this.usageAccessState = UsageAccessState.permissionNeeded,
    this.missions = const [],
    this.goals = const [],
    this.todayReflection,
    this.coachingSession,
    this.detectedPatterns = const [],
    this.activeAIGoal,
    this.coachingHistory = const CoachingHistory(),
    this.isCoachingLoopRunning = false,
    this.coachingLoopStep,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasFamily => family != null;
  bool get hasUsageAccess => usageAccessState == UsageAccessState.ready;
  int get completedMissionsCount =>
      missions.where((m) => m.isCompleted).length;
  bool get hasCoachingSession => coachingSession != null;
  String get patternSummary {
    final positive = detectedPatterns.where((p) => p.type == PatternType.positive).length;
    final concerning = detectedPatterns.where((p) => p.type == PatternType.concerning).length;
    if (positive > 0 && concerning == 0) return 'Looking great today! 🌟';
    if (concerning > 0 && positive == 0) return 'Some areas to focus on 💪';
    if (positive > 0 && concerning > 0) return 'Mixed signals — keep improving! 📊';
    return 'Waiting for your activity data...';
  }

  ChildDashboardState copyWith({
    ChildProfile? profile,
    Family? family,
    UsageSummary? usageSummary,
    UsageAccessState? usageAccessState,
    List<ChildMission>? missions,
    List<ChildGoal>? goals,
    DailyReflection? todayReflection,
    CoachingSession? coachingSession,
    List<DetectedPattern>? detectedPatterns,
    ChildGoal? activeAIGoal,
    CoachingHistory? coachingHistory,
    bool? isCoachingLoopRunning,
    CoachingSessionStatus? coachingLoopStep,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearReflection = false,
    bool clearAIGoal = false,
  }) {
    return ChildDashboardState(
      profile: profile ?? this.profile,
      family: family ?? this.family,
      usageSummary: usageSummary ?? this.usageSummary,
      usageAccessState: usageAccessState ?? this.usageAccessState,
      missions: missions ?? this.missions,
      goals: goals ?? this.goals,
      todayReflection: clearReflection
          ? null
          : (todayReflection ?? this.todayReflection),
      coachingSession: coachingSession ?? this.coachingSession,
      detectedPatterns: detectedPatterns ?? this.detectedPatterns,
      activeAIGoal: clearAIGoal ? null : (activeAIGoal ?? this.activeAIGoal),
      coachingHistory: coachingHistory ?? this.coachingHistory,
      isCoachingLoopRunning: isCoachingLoopRunning ?? this.isCoachingLoopRunning,
      coachingLoopStep: coachingLoopStep ?? this.coachingLoopStep,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChildDashboardController extends StateNotifier<ChildDashboardState> {
  final FamilyRepository _familyRepository;
  final UsageDataProvider _usageDataProvider;
  final LocalMissionRepository _missionRepository;
  final LocalGoalRepository _goalRepository;
  final LocalReflectionRepository _reflectionRepository;
  final NotificationProvider _notificationProvider;
  final CoachingLoopService _coachingLoopService;
  final MissionRealtimeService? _realtimeService;
  final LocalAiActivityService? _aiActivityService;
  final ReportRequestService? _reportRequestService;
  final ReportSchedulerService? _reportScheduler;
  bool _realtimeSubscribed = false;

  ChildDashboardController({
    required FamilyRepository familyRepository,
    required UsageDataProvider usageDataProvider,
    required LocalMissionRepository missionRepository,
    required LocalGoalRepository goalRepository,
    required LocalReflectionRepository reflectionRepository,
    required NotificationProvider notificationProvider,
    required CoachingLoopService coachingLoopService,
    MissionRealtimeService? realtimeService,
    LocalAiActivityService? aiActivityService,
    ReportRequestService? reportRequestService,
    ReportSchedulerService? reportScheduler,
  })  : _familyRepository = familyRepository,
        _usageDataProvider = usageDataProvider,
        _missionRepository = missionRepository,
        _goalRepository = goalRepository,
        _reflectionRepository = reflectionRepository,
        _notificationProvider = notificationProvider,
        _coachingLoopService = coachingLoopService,
        _realtimeService = realtimeService,
        _aiActivityService = aiActivityService,
        _reportRequestService = reportRequestService,
        _reportScheduler = reportScheduler,
        super(const ChildDashboardState());

  Future<void> loadDashboard(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _familyRepository.getChildProfileForUser(userId);
      Family? family;
      if (profile != null) {
        family = await _familyRepository.getFamilyForUser(userId);
      }

      final accessState = await _usageDataProvider.getUsageAccessState();
      if (accessState != UsageAccessState.ready) {
        final missions = profile == null
            ? const <ChildMission>[]
            : await _missionRepository.getMissions(childId: profile.id);
        state = state.copyWith(
          profile: profile,
          family: family,
          usageAccessState: accessState,
          missions: missions,
          isLoading: false,
        );
        return;
      }
      final usageSummary = await _usageDataProvider.getTodayUsage();
      final missions = profile == null
          ? const <ChildMission>[]
          : await _missionRepository.getMissions(childId: profile.id);
      final goals = await _goalRepository.getGoals();
      final reflection = await _reflectionRepository.getTodayReflection();
      final activeAIGoal = await _goalRepository.getActiveAIGoal();

      // Sync goal progress with actual usage data
      await _syncGoalProgressWithUsage(usageSummary, goals);
      final updatedGoals = await _goalRepository.getGoals();

      // Load coaching history
      await _coachingLoopService.loadHistory();
      final history = _coachingLoopService.getCoachingHistory();
      final todaySession = _coachingLoopService.getTodaySession();
      final patterns = _coachingLoopService.getLatestPatterns();

      state = state.copyWith(
        profile: profile,
        family: family,
        usageAccessState: accessState,
        usageSummary: usageSummary,
        missions: missions,
        goals: updatedGoals,
        todayReflection: reflection,
        activeAIGoal: activeAIGoal,
        coachingSession: todaySession,
        detectedPatterns: patterns,
        coachingHistory: history,
        isLoading: false,
      );

      // Auto-run coaching loop if not yet run today
      if (todaySession == null) {
        await runCoachingLoop();
      }

      _subscribeRealtime(profile);

      // Process any pending parent report requests queued for this device.
      // Requests stay queued until this device is online; each is completed
      // with a truthful ready/unavailable outcome.
      await _processPendingReportRequests(profile);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> _processPendingReportRequests(ChildProfile? profile) async {
    final requestService = _reportRequestService;
    final scheduler = _reportScheduler;
    if (profile == null || requestService == null || scheduler == null) return;

    final pending = await requestService.pendingRequestsForChild();
    for (final request in pending) {
      final requestId = request['id'] as String?;
      if (requestId == null) continue;
      await requestService.acknowledge(requestId);

      final period = switch (request['period'] as String?) {
        'weekly' => ReportPeriod.weekly,
        'monthly' => ReportPeriod.monthly,
        _ => ReportPeriod.daily,
      };

      final outcome = await scheduler.generateForRequest(
        childId: profile.id,
        childNickname: profile.nickname,
        familyId: profile.familyId,
        period: period,
      );

      await requestService.complete(
        requestId: requestId,
        status: outcome.status,
        reportId: outcome.report?.id,
        failureReason: outcome.reason.isEmpty ? null : outcome.reason,
      );
    }
  }

  /// Subscribes to live mission/event changes for this child, refreshing
  /// the dashboard when the parent creates or reviews an activity.
  void _subscribeRealtime(ChildProfile? profile) {
    final realtime = _realtimeService;
    if (realtime == null || _realtimeSubscribed || profile == null) return;
    _realtimeSubscribed = true;

    realtime.subscribeToChildMissionChanges(
      childProfileId: profile.id,
      onRefresh: () {
        if (!state.isLoading) loadDashboard(profile.userId);
      },
    );
  }

  /// Syncs all active goals' progress with actual usage data.
  Future<void> _syncGoalProgressWithUsage(
    UsageSummary usage,
    List<ChildGoal> goals,
  ) async {
    for (final goal in goals) {
      if (goal.status != GoalStatus.active) continue;

      int actualValue;
      switch (goal.type) {
        case GoalType.dailyFocus:
          actualValue = usage.focusMinutes;
          break;
        case GoalType.breakGoal:
          actualValue = usage.breakCount;
          break;
        case GoalType.digitalBalance:
          final gamingMin = usage.categories
              .where((c) => c.category.toLowerCase().contains('game'))
              .fold<int>(0, (s, c) => s + c.totalMinutes);
          actualValue = gamingMin <= goal.targetMinutes
              ? goal.targetMinutes
              : (goal.targetMinutes - (gamingMin - goal.targetMinutes))
                  .clamp(0, goal.targetMinutes);
          break;
        case GoalType.weeklyFocus:
          actualValue = usage.focusMinutes;
          break;
      }

      await _goalRepository.updateGoalProgress(goal.id, actualValue);
    }
  }

  /// Runs the complete coaching loop (auto + manual).
  Future<void> runCoachingLoop() async {
    state = state.copyWith(
      isCoachingLoopRunning: true,
      coachingLoopStep: CoachingSessionStatus.collecting,
    );

    try {
      // Run the real loop
      final session = await _coachingLoopService.runFullLoop();

      // Also generate dynamic missions based on patterns
      final updatedMissions = await _missionRepository.generateDynamicMissions(
        usage: state.usageSummary,
        patterns: session.patterns,
      );

      // Reload goals to get the newly generated AI goal
      final updatedGoals = await _goalRepository.getGoals();
      final activeAIGoal = await _goalRepository.getActiveAIGoal();
      final history = _coachingLoopService.getCoachingHistory();

      state = state.copyWith(
        coachingSession: session,
        detectedPatterns: session.patterns,
        missions: updatedMissions,
        goals: updatedGoals,
        activeAIGoal: activeAIGoal,
        coachingHistory: history,
        isCoachingLoopRunning: false,
        coachingLoopStep: CoachingSessionStatus.complete,
      );

      // Send a gentle notification about the new goal
      if (session.generatedGoal != null) {
        await _notificationProvider.showChildWellbeingNotification(
          id: session.generatedGoal!.id.hashCode.abs(),
          title: 'New Daily Goal! 🎯',
          body: session.generatedGoal!.title,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isCoachingLoopRunning: false,
        errorMessage: 'Coaching loop error: $e',
      );
    }
  }

/// Generates one AI-created activity from today's real usage summary.
  /// Returns a truthful explanation when nothing was created.
  Future<String> generateAiActivity() async {
    final service = _aiActivityService;
    if (service == null) {
      return 'AI activities are not available on this device.';
    }
    final result = await service.tryGenerate();
    if (result.isCreated) {
      final profile = state.profile;
      if (profile != null) {
        await loadDashboard(profile.userId);
      }
      return 'Created: ${result.mission!.title}';
    }
    return result.explanation ?? 'No AI activity was created.';
  }

  /// Re-checks usage access state after the user returns from system
  /// settings. Never opens the settings intent from here; the setup screen is
  /// the only entry point that requests access.
Future<void> refreshUsageAccess() async {
    final accessState = await _usageDataProvider.getUsageAccessState();
    if (accessState == UsageAccessState.ready) {
      final usage = await _usageDataProvider.getTodayUsage();
      state = state.copyWith(
        usageAccessState: accessState,
        usageSummary: usage,
      );
    } else {
      state = state.copyWith(usageAccessState: accessState);
    }
  }

  Future<void> toggleMission(String missionId) async {
    final mission = await _missionRepository.getMissionById(missionId);
    if (mission == null) return;

    if (mission.isCompleted) {
      await _missionRepository.saveMission(
        mission.copyWith(
          status: MissionStatus.assigned,
          currentMinutes: 0,
        ),
      );
    } else {
      await _missionRepository.completeMission(missionId);
      // Gentle wellbeing celebration notification
      await _notificationProvider.showChildWellbeingNotification(
        id: missionId.hashCode.abs(),
        title: 'Activity Complete!',
        body: 'Nice work finishing "${mission.title}"!',
      );
    }

    final updated = await _missionRepository.getMissions();
    state = state.copyWith(missions: updated);
  }

  Future<void> saveReflection({
    required ReflectionMood mood,
    String? notes,
  }) async {
    final now = DateTime.now();
    final reflection = DailyReflection(
      id: 'ref-${now.millisecondsSinceEpoch}',
      date: DateTime(now.year, now.month, now.day),
      mood: mood,
      notes: notes,
      createdAt: now,
    );
    await _reflectionRepository.saveReflection(reflection);
    state = state.copyWith(todayReflection: reflection);
  }

  Future<void> deleteTodayReflection() async {
    final current = state.todayReflection;
    if (current != null) {
      await _reflectionRepository.deleteReflection(current.id);
      state = state.copyWith(clearReflection: true);
    }
  }
}

final childDashboardControllerProvider =
    StateNotifierProvider<ChildDashboardController, ChildDashboardState>((ref) {
  final familyRepo = ref.watch(familyRepositoryProvider);
  final usageProvider = ref.watch(usageDataProvider);
  final missionRepo = ref.watch(localMissionRepositoryProvider);
  final goalRepo = ref.watch(localGoalRepositoryProvider);
  final reflectionRepo = ref.watch(localReflectionRepositoryProvider);
  final notifProvider = ref.watch(notificationProvider);
  final coachingLoop = ref.watch(coachingLoopServiceProvider);
  final realtimeService = ref.watch(missionRealtimeServiceProvider);
  final aiActivityService = ref.watch(localAiActivityServiceProvider);
  final reportRequestService = ref.watch(reportRequestServiceProvider);
  final reportScheduler = ref.watch(reportSchedulerServiceProvider);

  return ChildDashboardController(
    familyRepository: familyRepo,
    usageDataProvider: usageProvider,
    missionRepository: missionRepo,
    goalRepository: goalRepo,
    reflectionRepository: reflectionRepo,
    notificationProvider: notifProvider,
    coachingLoopService: coachingLoop,
    realtimeService: realtimeService,
    aiActivityService: aiActivityService,
    reportRequestService: reportRequestService,
    reportScheduler: reportScheduler,
  );
});
