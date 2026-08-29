import '../models/achievement_model.dart';

abstract class LocalAchievementRepository {
  Future<List<ChildAchievement>> getAchievements();
  Future<ChildAchievement?> getAchievementById(String id);
  Future<void> saveAchievement(ChildAchievement achievement);
  Future<void> updateAchievementProgress(String id, int value, bool unlock);
}

class InMemoryLocalAchievementRepository implements LocalAchievementRepository {
  final Map<String, ChildAchievement> _achievements = {};

  InMemoryLocalAchievementRepository() {
    _initDefaultAchievements();
  }

  void _initDefaultAchievements() {
    final defaults = [
      const ChildAchievement(
        id: 'ach-focus-starter',
        title: 'Focus Starter',
        description: 'Complete your first 20-minute uninterrupted focus quest.',
        icon: 'bolt_rounded',
        type: AchievementType.focusStarter,
        isUnlocked: true,
        progress: 1.0,
        requirementValue: 20,
        currentValue: 20,
        requirementLabel: '20 min focus',
      ),
      const ChildAchievement(
        id: 'ach-break-master',
        title: 'Break Master',
        description: 'Take 5 mindful screen breaks across a single day.',
        icon: 'self_improvement_rounded',
        type: AchievementType.breakMaster,
        isUnlocked: true,
        progress: 1.0,
        requirementValue: 5,
        currentValue: 5,
        requirementLabel: '5 mindful breaks',
      ),
      const ChildAchievement(
        id: 'ach-deep-focus',
        title: 'Deep Focus Sprint',
        description: 'Complete a qualifying uninterrupted 30-minute deep focus session.',
        icon: 'psychology_rounded',
        type: AchievementType.deepFocus,
        isUnlocked: true,
        progress: 1.0,
        requirementValue: 30,
        currentValue: 30,
        requirementLabel: '30 min session',
      ),
      const ChildAchievement(
        id: 'ach-7-day-balance',
        title: '7-Day Balance',
        description: 'Maintain balanced screen habits and meet daily focus goals for 7 days.',
        icon: 'calendar_month_rounded',
        type: AchievementType.sevenDayBalance,
        isUnlocked: false,
        progress: 0.71, // 5 of 7 days
        requirementValue: 7,
        currentValue: 5,
        requirementLabel: '5 / 7 days',
      ),
      const ChildAchievement(
        id: 'ach-consistency-champ',
        title: 'Consistency Champion',
        description: 'Achieve your focus goals 14 days in a row.',
        icon: 'military_tech_rounded',
        type: AchievementType.consistencyChampion,
        isUnlocked: false,
        progress: 0.35, // 5 of 14 days
        requirementValue: 14,
        currentValue: 5,
        requirementLabel: '5 / 14 days',
      ),
    ];

    for (final a in defaults) {
      _achievements[a.id] = a;
    }
  }

  @override
  Future<List<ChildAchievement>> getAchievements() async {
    return _achievements.values.toList();
  }

  @override
  Future<ChildAchievement?> getAchievementById(String id) async {
    return _achievements[id];
  }

  @override
  Future<void> saveAchievement(ChildAchievement achievement) async {
    _achievements[achievement.id] = achievement;
  }

  @override
  Future<void> updateAchievementProgress(String id, int value, bool unlock) async {
    final existing = _achievements[id];
    if (existing == null) return;

    final progressRatio = existing.requirementValue > 0
        ? (value / existing.requirementValue).clamp(0.0, 1.0)
        : (unlock ? 1.0 : 0.0);

    _achievements[id] = existing.copyWith(
      currentValue: value,
      progress: progressRatio,
      isUnlocked: unlock || progressRatio >= 1.0,
      unlockedAt: (unlock || progressRatio >= 1.0) ? (existing.unlockedAt ?? DateTime.now()) : null,
    );
  }
}
