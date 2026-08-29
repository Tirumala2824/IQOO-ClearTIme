import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../../core/providers/providers.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/family_model.dart';
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

class ChildDashboardState {
  final ChildProfile? profile;
  final Family? family;
  final UsageSummary usageSummary;
  final bool hasPermission;
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
    this.hasPermission = true,
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
  int get completedMissionsCount =>
      missions.where((m) => m.isCompleted).length;
  int get totalPoints => missions
      .where((m) => m.isCompleted)
      .fold(0, (sum, m) => sum + m.points);
  bool get hasCoachingSession => coachingSession != null;
  String get patternSummary {
    final positive = detectedPatterns.where((p) => p.type == PatternType.positive).length;
    final concerning = detectedPatterns.where((p) => p.type == PatternType.concerning).length;
    if (positive > 0 && concerning == 0) return 'Looking great today! 🌟';
    if (concerning > 0 && positive == 0) return 'Some areas to focus on 💪';
    if (positive > 0 && concerning > 0) return 'Mixed signals — keep improving! 📊';
    return 'Analyzing your habits...';
  }

  ChildDashboardState copyWith({
    ChildProfile? profile,
    Family? family,
    UsageSummary? usageSummary,
    bool? hasPermission,
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
      hasPermission: hasPermission ?? this.hasPermission,
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

  ChildDashboardController({
    required FamilyRepository familyRepository,
    required UsageDataProvider usageDataProvider,
    required LocalMissionRepository missionRepository,
    required LocalGoalRepository goalRepository,
    required LocalReflectionRepository reflectionRepository,
    required NotificationProvider notificationProvider,
    required CoachingLoopService coachingLoopService,
  })  : _familyRepository = familyRepository,
        _usageDataProvider = usageDataProvider,
        _missionRepository = missionRepository,
        _goalRepository = goalRepository,
        _reflectionRepository = reflectionRepository,
        _notificationProvider = notificationProvider,
        _coachingLoopService = coachingLoopService,
        super(const ChildDashboardState());

  Future<void> loadDashboard(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _familyRepository.getChildProfileForUser(userId);
      Family? family;
      if (profile != null) {
        family = await _familyRepository.getFamilyForUser(userId);
      }

      final hasPermission = await _usageDataProvider.hasUsagePermission();
      final usageSummary = await _usageDataProvider.getTodayUsage();
      final missions = await _missionRepository.getMissions();
      final goals = await _goalRepository.getGoals();
      final reflection = await _reflectionRepository.getTodayReflection();
      final activeAIGoal = await _goalRepository.getActiveAIGoal();

      // Sync goal progress with actual usage data
      await _syncGoalProgressWithUsage(usageSummary, goals);
      final updatedGoals = await _goalRepository.getGoals();

      // Load coaching history
      final history = _coachingLoopService.getCoachingHistory();
      final todaySession = _coachingLoopService.getTodaySession();
      final patterns = _coachingLoopService.getLatestPatterns();

      state = state.copyWith(
        profile: profile,
        family: family,
        hasPermission: hasPermission,
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
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
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

  Future<void> requestUsagePermission() async {
    await _usageDataProvider.requestUsagePermission();
    final hasPerm = await _usageDataProvider.hasUsagePermission();
    final usage = await _usageDataProvider.getTodayUsage();
    state = state.copyWith(hasPermission: hasPerm, usageSummary: usage);
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
        title: 'Mission Complete! 🌟',
        body: 'Awesome job completing "${mission.title}"! +${mission.points} wellbeing points earned.',
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

  return ChildDashboardController(
    familyRepository: familyRepo,
    usageDataProvider: usageProvider,
    missionRepository: missionRepo,
    goalRepository: goalRepo,
    reflectionRepository: reflectionRepo,
    notificationProvider: notifProvider,
    coachingLoopService: coachingLoop,
  );
});
