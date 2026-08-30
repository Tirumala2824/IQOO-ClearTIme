import '../../core/services/abstractions/local_usage_store.dart';
import '../../data/models/usage_models.dart';
import 'encrypted_device_store.dart';
import 'retention_config.dart';

/// Encrypted on-device store for raw usage records and daily aggregates.
///
/// Raw usage is stored encrypted under a keychain-held master key and is
/// retained only as long as [RetentionConfig] allows. No raw usage ever
/// leaves the device.
class SecureLocalUsageStore implements LocalUsageStore {
  final EncryptedDeviceStore _store;
  final RetentionConfig retentionConfig;
  bool _isInitialized = false;

  SecureLocalUsageStore({
    EncryptedDeviceStore? store,
    this.retentionConfig = RetentionConfig.standard,
  }) : _store = store ?? EncryptedDeviceStore();

  @override
  Future<void> initialize() async {
    await _store.initialize();
    _isInitialized = true;
  }

  @override
  Future<void> saveUsage(UsageRecord usage) async {
    await initialize();
    await _store.putJson(
      EncryptedDeviceStore.usageRecordsBox,
      usage.id,
      usage.toJson(),
    );
  }

  @override
  Future<void> saveUsageBatch(List<UsageRecord> records) async {
    for (final r in records) {
      await saveUsage(r);
    }
  }

  @override
  Future<List<UsageRecord>> getUsage({DateTime? start, DateTime? end}) async {
    await initialize();
    final records = <UsageRecord>[];
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.usageRecordsBox,
      onCorrupt: (key, _) =>
          _store.delete(EncryptedDeviceStore.usageRecordsBox, key),
    );
    for (final json in jsons) {
      try {
        final record = UsageRecord.fromJson(json);
        if (start != null && record.startTime.isBefore(start)) continue;
        if (end != null && record.endTime.isAfter(end)) continue;
        records.add(record);
      } catch (_) {
        // Skip corrupted records.
      }
    }
    records.sort((a, b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  @override
  Future<void> saveDailyAggregate(DailyAggregate aggregate) async {
    await initialize();
    await _store.putJson(
      EncryptedDeviceStore.usageAggregatesBox,
      aggregate.dateString,
      aggregate.toJson(),
    );
  }

  @override
  Future<DailyAggregate?> getDailyAggregate(DateTime date) async {
    await initialize();
    final dateStr = _dateString(date);
    final json = await _store.getJson(
      EncryptedDeviceStore.usageAggregatesBox,
      dateStr,
    );
    if (json == null) return null;
    try {
      return DailyAggregate.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DailyAggregate>> getWeeklyAggregate() async {
    await initialize();
    final list = await _getAllAggregates();
    list.sort((a, b) => b.dateString.compareTo(a.dateString));
    return list.take(7).toList();
  }

  @override
  Future<List<DailyAggregate>> getDailyAggregatesInRange(
      String start, String end) async {
    await initialize();
    final list = await _getAllAggregates();
    return list
        .where((a) =>
            a.dateString.compareTo(start) >= 0 &&
            a.dateString.compareTo(end) <= 0)
        .toList()
      ..sort((a, b) => a.dateString.compareTo(b.dateString));
  }

  Future<List<DailyAggregate>> _getAllAggregates() async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.usageAggregatesBox,
      onCorrupt: (key, _) =>
          _store.delete(EncryptedDeviceStore.usageAggregatesBox, key),
    );
    final aggregates = <DailyAggregate>[];
    for (final json in jsons) {
      try {
        aggregates.add(DailyAggregate.fromJson(json));
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    return aggregates;
  }

  @override
  Future<void> deleteUsage(String id) async {
    await initialize();
    await _store.delete(EncryptedDeviceStore.usageRecordsBox, id);
  }

  @override
  Future<int> deleteExpiredUsage() async {
    await initialize();
    final rawCutoff =
        DateTime.now().subtract(Duration(days: retentionConfig.rawUsageRetentionDays));
    var deleted = 0;

    final rawJsons = await _store.getAllJson(EncryptedDeviceStore.usageRecordsBox);
    for (final json in rawJsons) {
      try {
        final record = UsageRecord.fromJson(json);
        if (record.endTime.isBefore(rawCutoff)) {
          await deleteUsage(record.id);
          deleted++;
        }
      } catch (_) {
        // Corrupted entries are removed during reads.
      }
    }

    final aggCutoff = DateTime.now()
        .subtract(Duration(days: retentionConfig.aggregateRetentionDays));
    final aggJsons =
        await _store.getAllJson(EncryptedDeviceStore.usageAggregatesBox);
    for (final json in aggJsons) {
      try {
        final agg = DailyAggregate.fromJson(json);
        if (agg.date.isBefore(aggCutoff)) {
          await _store.delete(EncryptedDeviceStore.usageAggregatesBox, agg.dateString);
          deleted++;
        }
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    return deleted;
  }

  @override
  Future<void> wipeAllLocalData() async {
    await initialize();
    await _store.clearBox(EncryptedDeviceStore.usageRecordsBox);
    await _store.clearBox(EncryptedDeviceStore.usageAggregatesBox);
  }

  bool get isInitialized => _isInitialized;

  String _dateString(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
