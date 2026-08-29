/// Abstract interface for local encrypted on-device database storage.
///
/// STRICT PRIVACY RULE:
/// Raw application usage and granular timestamps NEVER leave the device.
/// Only encrypted local storage (e.g. SQLite / Hive with SQLCipher) is used.
abstract class LocalUsageStore {
  /// Initializes the local secure storage engine.
  Future<void> initialize();

  /// Saves an aggregated local wellbeing snapshot.
  Future<void> saveAggregatedSnapshot({
    required DateTime date,
    required Map<String, dynamic> summary,
  });

  /// Retrieves local aggregated data for a specific date range.
  Future<List<Map<String, dynamic>>> getSnapshots({
    required DateTime start,
    required DateTime end,
  });

  /// Purges local records older than retention threshold (e.g. 30 days).
  Future<int> purgeOldSnapshots({required int retentionDays});

  /// Completely wipes all local usage data upon request or logout.
  Future<void> wipeAllLocalData();
}
