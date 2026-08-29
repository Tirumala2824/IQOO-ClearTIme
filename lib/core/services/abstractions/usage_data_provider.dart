/// Abstract definition for future on-device local usage data collection.
///
/// Note: No raw usage tables exist in Supabase and no cloud telemetry is transmitted.
/// Phase 1 defines the contract for future local device telemetry adapters.
abstract class UsageDataProvider {
  /// Checks whether local usage access permissions are granted on the Android device.
  Future<bool> hasUsagePermission();

  /// Requests the user to grant local usage access permission in Android Settings.
  Future<bool> requestUsagePermission();

  /// Fetches aggregated usage summaries stored locally between [start] and [end].
  /// Raw per-app timestamps stay on device.
  Future<Map<String, dynamic>> getAggregatedUsage({
    required DateTime start,
    required DateTime end,
  });

  /// Streams real-time local wellbeing events (e.g. app switch, screen unlock) for local processing only.
  Stream<Map<String, dynamic>> watchLocalEvents();
}
