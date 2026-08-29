import '../models/reflection_model.dart';

abstract class LocalReflectionRepository {
  Future<List<DailyReflection>> getReflections();
  Future<DailyReflection?> getTodayReflection();
  Future<void> saveReflection(DailyReflection reflection);
  Future<void> deleteReflection(String id);
  Future<void> clearAllReflections();
}

class InMemoryLocalReflectionRepository implements LocalReflectionRepository {
  final Map<String, DailyReflection> _reflections = {};

  InMemoryLocalReflectionRepository() {
    // Start empty — reflections are created by the child
  }


  @override
  Future<List<DailyReflection>> getReflections() async {
    final list = _reflections.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<DailyReflection?> getTodayReflection() async {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final todays = _reflections.values.where((r) =>
        r.date.year == todayDate.year &&
        r.date.month == todayDate.month &&
        r.date.day == todayDate.day).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return todays.isNotEmpty ? todays.first : null;
  }

  @override
  Future<void> saveReflection(DailyReflection reflection) async {
    // Remove previous reflections for the same date to keep 1 daily reflection
    _reflections.removeWhere((key, r) =>
        r.date.year == reflection.date.year &&
        r.date.month == reflection.date.month &&
        r.date.day == reflection.date.day);
    _reflections[reflection.id] = reflection;
  }

  @override
  Future<void> deleteReflection(String id) async {
    _reflections.remove(id);
  }

  @override
  Future<void> clearAllReflections() async {
    _reflections.clear();
  }
}
