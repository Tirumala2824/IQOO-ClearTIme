import '../../../data/models/usage_models.dart';

/// Abstract interface for local encrypted on-device database storage.
///
/// STRICT PRIVACY RULE:
/// Raw application usage and granular timestamps NEVER leave the device.
/// Only encrypted local storage is used.
abstract class LocalUsageStore {
  /// Initializes the local secure storage engine.
  Future<void> initialize();

  /// Saves a raw local usage record to encrypted storage.
  Future<void> saveUsage(UsageRecord usage);

  /// Saves a batch of raw local usage records.
  Future<void> saveUsageBatch(List<UsageRecord> records);

  /// Retrieves raw local usage records optionally filtered by date.
  Future<List<UsageRecord>> getUsage({DateTime? start, DateTime? end});

  /// Saves a daily aggregate summary.
  Future<void> saveDailyAggregate(DailyAggregate aggregate);

  /// Retrieves a daily aggregate summary for a specific date.
  Future<DailyAggregate?> getDailyAggregate(DateTime date);

  /// Retrieves the past 7 daily aggregates for weekly calculations.
  Future<List<DailyAggregate>> getWeeklyAggregate();

  /// Retrieves daily aggregates within an inclusive date range (YYYY-MM-DD format).
  Future<List<DailyAggregate>> getDailyAggregatesInRange(String start, String end);

  /// Deletes a specific usage record by ID.
  Future<void> deleteUsage(String id);

  /// Deletes expired usage records based on retention policy (e.g., >30 days).
  Future<int> deleteExpiredUsage();

  /// Completely wipes all local raw and aggregated usage data.
  Future<void> wipeAllLocalData();
}
