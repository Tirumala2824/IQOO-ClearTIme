import '../models/achievement_model.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class LocalAchievementRepository {
  Future<List<ChildAchievement>> getAchievements();
  Future<ChildAchievement?> getAchievementById(String id);
  Future<void> saveAchievement(ChildAchievement achievement);
  Future<void> updateAchievementProgress(String id, int value, bool unlock);
}

/// Encrypted on-device achievement state.
///
/// The repository starts empty: no badges are pre-seeded. An achievement
/// record exists only after it was computed from real usage analytics.
class EncryptedLocalAchievementRepository
    implements LocalAchievementRepository {
  final EncryptedDeviceStore _store;

  EncryptedLocalAchievementRepository({required EncryptedDeviceStore store})
      : _store = store;

  @override
  Future<List<ChildAchievement>> getAchievements() async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.goalsBox,
      onCorrupt: (key, _) => _store.delete(EncryptedDeviceStore.goalsBox, key),
    );
    final achievements = <ChildAchievement>[];
    for (final json in jsons) {
      try {
        final achievement = ChildAchievement.fromJson(json);
        if (achievement.id.startsWith('ach-')) {
          achievements.add(achievement);
        }
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    achievements.sort((a, b) => b.id.compareTo(b.id));
    return achievements;
  }

  @override
  Future<ChildAchievement?> getAchievementById(String id) async {
    final json = await _store.getJson(EncryptedDeviceStore.goalsBox, id);
    if (json == null) return null;
    try {
      return ChildAchievement.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveAchievement(ChildAchievement achievement) async {
    await _store.putJson(
      EncryptedDeviceStore.goalsBox,
      achievement.id,
      achievement.toJson(),
    );
  }

  @override
  Future<void> updateAchievementProgress(String id, int value, bool unlock) async {
    final existing = await getAchievementById(id);
    if (existing == null) return;

    final progressRatio = existing.requirementValue > 0
        ? (value / existing.requirementValue).clamp(0.0, 1.0)
        : (unlock ? 1.0 : 0.0);

    await saveAchievement(existing.copyWith(
      currentValue: value,
      progress: progressRatio,
      isUnlocked: unlock || progressRatio >= 1.0,
      unlockedAt: (unlock || progressRatio >= 1.0)
          ? (existing.unlockedAt ?? DateTime.now())
          : null,
    ));
  }
}