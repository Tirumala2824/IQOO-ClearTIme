import '../models/reflection_model.dart';
import '../../services/storage/encrypted_device_store.dart';
import '../../services/storage/retention_config.dart';

abstract class LocalReflectionRepository {
  Future<List<DailyReflection>> getReflections();
  Future<DailyReflection?> getTodayReflection();
  Future<DailyReflection?> getReflectionById(String id);
  Future<void> saveReflection(DailyReflection reflection);
  Future<void> updateReflection(DailyReflection reflection);
  Future<void> deleteReflection(String id);
  Future<void> clearAllReflections();
  /// Number of stored entries that failed decryption/decoding on the last
  /// read. Used to surface a truthful "recovery" state.
  Future<int> getCorruptEntryCount();
}

/// Encrypted on-device persistence for private reflections.
///
/// Reflections are private, user-authored records. They are never shown to
/// parents and never included in AI contexts or report uploads. Retention is
/// capped at [RetentionConfig.maxReflectionsStored] most-recent entries.
class EncryptedLocalReflectionRepository implements LocalReflectionRepository {
  final EncryptedDeviceStore _store;
  final RetentionConfig _retentionConfig;
  int _corruptCount = 0;

  EncryptedLocalReflectionRepository({
    required EncryptedDeviceStore store,
    RetentionConfig retentionConfig = RetentionConfig.standard,
  })  : _store = store,
        _retentionConfig = retentionConfig;

  @override
  Future<List<DailyReflection>> getReflections() async {
    var corrupt = 0;
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.reflectionsBox,
      onCorrupt: (key, _) {
        corrupt++;
      },
    );
    final reflections = <DailyReflection>[];
    for (final json in jsons) {
      try {
        reflections.add(DailyReflection.fromJson(json));
      } catch (_) {
        corrupt++;
      }
    }
    _corruptCount = corrupt;
    reflections.sort((a, b) => b.date.compareTo(a.date));
    return reflections;
  }

  @override
  Future<DailyReflection?> getTodayReflection() async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final reflections = await getReflections();
    final todays = reflections
        .where((r) =>
            r.date.year == todayDate.year &&
            r.date.month == todayDate.month &&
            r.date.day == todayDate.day)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return todays.isNotEmpty ? todays.first : null;
  }

  @override
  Future<DailyReflection?> getReflectionById(String id) async {
    final json = await _store.getJson(EncryptedDeviceStore.reflectionsBox, id);
    if (json == null) return null;
    try {
      return DailyReflection.fromJson(json);
    } catch (_) {
      _corruptCount++;
      return null;
    }
  }

  @override
  Future<void> saveReflection(DailyReflection reflection) async {
    await _store.putJson(
      EncryptedDeviceStore.reflectionsBox,
      reflection.id,
      reflection.toJson(),
    );
    await _enforceRetention();
  }

  @override
  Future<void> updateReflection(DailyReflection reflection) async {
    // Update is only allowed for an existing record; otherwise it is a create.
    final existing = await getReflectionById(reflection.id);
    if (existing == null) {
      await saveReflection(reflection);
      return;
    }
    await _store.putJson(
      EncryptedDeviceStore.reflectionsBox,
      reflection.id,
      reflection.toJson(),
    );
  }

  @override
  Future<void> deleteReflection(String id) async {
    await _store.delete(EncryptedDeviceStore.reflectionsBox, id);
  }

  @override
  Future<void> clearAllReflections() async {
    await _store.clearBox(EncryptedDeviceStore.reflectionsBox);
    _corruptCount = 0;
  }

  @override
  Future<int> getCorruptEntryCount() async {
    await getReflections();
    return _corruptCount;
  }

  Future<void> _enforceRetention() async {
    final reflections = await getReflections();
    if (reflections.length <= _retentionConfig.maxReflectionsStored) return;
    final toDelete = reflections
        .skip(_retentionConfig.maxReflectionsStored)
        .map((r) => r.id)
        .toList();
    for (final id in toDelete) {
      await deleteReflection(id);
    }
  }
}
