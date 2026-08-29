import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../../core/providers/providers.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/family_model.dart';
import '../../../data/models/usage_models.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/reflection_model.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/local_mission_repository.dart';
import '../../../data/repositories/local_goal_repository.dart';
import '../../../data/repositories/local_reflection_repository.dart';
import '../../../core/services/abstractions/usage_data_provider.dart';
import '../../../core/services/abstractions/notification_provider.dart';

class ChildDashboardState {
  final ChildProfile? profile;
  final Family? family;
  final UsageSummary usageSummary;
  final bool hasPermission;
  final List<ChildMission> missions;
  final List<ChildGoal> goals;
  final DailyReflection? todayReflection;
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
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasFamily => family != null;
  int get completedMissionsCount =>
      missions.where((m) => m.isCompleted).length;
  int get totalPoints => missions
      .where((m) => m.isCompleted)
      .fold(0, (sum, m) => sum + m.points);

  ChildDashboardState copyWith({
    ChildProfile? profile,
    Family? family,
    UsageSummary? usageSummary,
    bool? hasPermission,
    List<ChildMission>? missions,
    List<ChildGoal>? goals,
    DailyReflection? todayReflection,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
    bool clearReflection = false,
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

  ChildDashboardController({
    required FamilyRepository familyRepository,
    required UsageDataProvider usageDataProvider,
    required LocalMissionRepository missionRepository,
    required LocalGoalRepository goalRepository,
    required LocalReflectionRepository reflectionRepository,
    required NotificationProvider notificationProvider,
  })  : _familyRepository = familyRepository,
        _usageDataProvider = usageDataProvider,
        _missionRepository = missionRepository,
        _goalRepository = goalRepository,
        _reflectionRepository = reflectionRepository,
        _notificationProvider = notificationProvider,
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

      state = state.copyWith(
        profile: profile,
        family: family,
        hasPermission: hasPermission,
        usageSummary: usageSummary,
        missions: missions,
        goals: goals,
        todayReflection: reflection,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
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
          status: MissionStatus.available,
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

  return ChildDashboardController(
    familyRepository: familyRepo,
    usageDataProvider: usageProvider,
    missionRepository: missionRepo,
    goalRepository: goalRepo,
    reflectionRepository: reflectionRepo,
    notificationProvider: notifProvider,
  );
});
