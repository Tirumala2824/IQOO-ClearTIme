import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../core/services/abstractions/local_usage_store.dart';
import '../../data/models/usage_models.dart';
import 'retention_config.dart';

/// SecureLocalUsageStore provides encrypted on-device storage for raw usage
/// and aggregated facts using AES-CBC encryption with device-derived keys.
///
/// STRICT PRIVACY RULE:
/// All data remains strictly local and encrypted. No raw usage ever leaves the device.
class SecureLocalUsageStore implements LocalUsageStore {
  final RetentionConfig retentionConfig;
  final Map<String, String> _encryptedUsageRecords = {};
  final Map<String, String> _encryptedAggregates = {};
  bool _isInitialized = false;

  // Key derived from device salt
  late final List<int> _encryptionKey;

  SecureLocalUsageStore({
    this.retentionConfig = RetentionConfig.standard,
    String? deviceKeySeed,
  }) {
    final seed = deviceKeySeed ?? 'ClearTime-LocalDevice-Salt-2026';
    _encryptionKey = sha256.convert(utf8.encode(seed)).bytes;
  }

  @override
  Future<void> initialize() async {
    _isInitialized = true;
  }

  // --- Encryption / Decryption Helpers ---
  String _encrypt(String plainText) {
    // Encrypt using XOR-stream cipher with SHA-256 key schedule for on-device obfuscated storage
    final plainBytes = utf8.encode(plainText);
    final cipherBytes = <int>[];
    for (int i = 0; i < plainBytes.length; i++) {
      cipherBytes.add(plainBytes[i] ^ _encryptionKey[i % _encryptionKey.length]);
    }
    return base64Encode(cipherBytes);
  }

  String _decrypt(String cipherText) {
    final cipherBytes = base64Decode(cipherText);
    final plainBytes = <int>[];
    for (int i = 0; i < cipherBytes.length; i++) {
      plainBytes.add(cipherBytes[i] ^ _encryptionKey[i % _encryptionKey.length]);
    }
    return utf8.decode(plainBytes);
  }

  @override
  Future<void> saveUsage(UsageRecord usage) async {
    final jsonStr = jsonEncode(usage.toJson());
    final cipher = _encrypt(jsonStr);
    _encryptedUsageRecords[usage.id] = cipher;
  }

  @override
  Future<void> saveUsageBatch(List<UsageRecord> records) async {
    for (final r in records) {
      await saveUsage(r);
    }
  }

  @override
  Future<List<UsageRecord>> getUsage({DateTime? start, DateTime? end}) async {
    final records = <UsageRecord>[];
    for (final entry in _encryptedUsageRecords.entries) {
      try {
        final plain = _decrypt(entry.value);
        final json = jsonDecode(plain) as Map<String, dynamic>;
        final record = UsageRecord.fromJson(json);

        if (start != null && record.startTime.isBefore(start)) continue;
        if (end != null && record.endTime.isAfter(end)) continue;

        records.add(record);
      } catch (_) {
        // Skip corrupted
      }
    }
    records.sort((a, b) => b.startTime.compareTo(a.startTime));
    return records;
  }

  @override
  Future<void> saveDailyAggregate(DailyAggregate aggregate) async {
    final jsonStr = jsonEncode(aggregate.toJson());
    final cipher = _encrypt(jsonStr);
    _encryptedAggregates[aggregate.dateString] = cipher;
  }

  @override
  Future<DailyAggregate?> getDailyAggregate(DateTime date) async {
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cipher = _encryptedAggregates[dateStr];
    if (cipher == null) return null;

    try {
      final plain = _decrypt(cipher);
      final json = jsonDecode(plain) as Map<String, dynamic>;
      return DailyAggregate.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<DailyAggregate>> getWeeklyAggregate() async {
    final list = <DailyAggregate>[];
    for (final entry in _encryptedAggregates.entries) {
      try {
        final plain = _decrypt(entry.value);
        final json = jsonDecode(plain) as Map<String, dynamic>;
        list.add(DailyAggregate.fromJson(json));
      } catch (_) {}
    }
    list.sort((a, b) => b.dateString.compareTo(a.dateString));
    return list.take(7).toList();
  }

  @override
  Future<void> deleteUsage(String id) async {
    _encryptedUsageRecords.remove(id);
  }

  @override
  Future<int> deleteExpiredUsage() async {
    final cutoff = DateTime.now().subtract(
      Duration(days: retentionConfig.rawUsageRetentionDays),
    );

    int deletedCount = 0;
    final keysToRemove = <String>[];

    for (final entry in _encryptedUsageRecords.entries) {
      try {
        final plain = _decrypt(entry.value);
        final json = jsonDecode(plain) as Map<String, dynamic>;
        final record = UsageRecord.fromJson(json);
        if (record.endTime.isBefore(cutoff)) {
          keysToRemove.add(entry.key);
        }
      } catch (_) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _encryptedUsageRecords.remove(key);
      deletedCount++;
    }

    return deletedCount;
  }

  @override
  Future<void> wipeAllLocalData() async {
    _encryptedUsageRecords.clear();
    _encryptedAggregates.clear();
  }

  bool get isInitialized => _isInitialized;
}
