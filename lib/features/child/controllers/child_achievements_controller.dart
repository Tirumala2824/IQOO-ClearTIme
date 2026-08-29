import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/repositories/local_achievement_repository.dart';
import '../../../services/analytics/local_analytics_service.dart';

class ChildAchievementsState {
  final List<ChildAchievement> achievements;
  final bool isLoading;
  final String? errorMessage;

  const ChildAchievementsState({
    this.achievements = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  int get unlockedCount => achievements.where((a) => a.isUnlocked).length;

  ChildAchievementsState copyWith({
    List<ChildAchievement>? achievements,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ChildAchievementsState(
      achievements: achievements ?? this.achievements,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ChildAchievementsController extends StateNotifier<ChildAchievementsState> {
  final LocalAchievementRepository _repository;
  final LocalAnalyticsService _analyticsService;

  ChildAchievementsController({
    required LocalAchievementRepository repository,
    required LocalAnalyticsService analyticsService,
  })  : _repository = repository,
        _analyticsService = analyticsService,
        super(const ChildAchievementsState()) {
    loadAchievements();
  }

  Future<void> loadAchievements() async {
    state = state.copyWith(isLoading: true);
    try {
      final list = await _repository.getAchievements();
      state = state.copyWith(achievements: list, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> evaluateAgainstAnalytics({
    required int focusMinutes,
    required int breakCount,
    required int consecutiveDaysGoalMet,
    required int maxSingleFocusSession,
  }) async {
    final list = await _repository.getAchievements();
    for (final ach in list) {
      final meets = _analyticsService.evaluateAchievementCriteria(
        type: ach.type,
        focusMinutes: focusMinutes,
        breakCount: breakCount,
        consecutiveDaysGoalMet: consecutiveDaysGoalMet,
        maxSingleFocusSession: maxSingleFocusSession,
      );
      if (meets && !ach.isUnlocked) {
        await _repository.updateAchievementProgress(ach.id, ach.requirementValue, true);
      }
    }
    await loadAchievements();
  }
}

final childAchievementsControllerProvider =
    StateNotifierProvider<ChildAchievementsController, ChildAchievementsState>((ref) {
  final repo = ref.watch(localAchievementRepositoryProvider);
  final analytics = ref.watch(localAnalyticsServiceProvider);
  return ChildAchievementsController(repository: repo, analyticsService: analytics);
});
