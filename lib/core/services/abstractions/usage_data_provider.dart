import '../../../data/models/usage_models.dart';

/// Abstract definition for on-device local usage data collection.
///
/// CRITICAL PRIVACY RULE:
/// Raw application usage and granular timestamps NEVER leave the device.
/// No raw usage data is ever sent to Supabase or cloud telemetry.
abstract class UsageDataProvider {
  /// Checks whether local usage access permissions are granted on the Android device.
  Future<bool> hasUsagePermission();

  /// Requests the user to grant local usage access permission in Android Settings.
  Future<bool> requestUsagePermission();

  /// Fetches aggregated usage summary for today.
  Future<UsageSummary> getTodayUsage();

  /// Fetches daily usage breakdown for recent days.
  Future<List<DailyUsage>> getDailyUsage();

  /// Fetches weekly usage breakdown for the past 7 days.
  Future<List<DailyUsage>> getWeeklyUsage();

  /// Fetches monthly usage breakdown.
  Future<List<DailyUsage>> getMonthlyUsage();

  /// Fetches category breakdown of app usage.
  Future<List<CategoryUsage>> getCategoryUsage();

  /// Fetches the local usage timeline entries.
  Future<List<UsageTimelineEntry>> getUsageTimeline();

  /// Fetches recorded focus sessions.
  Future<List<FocusSession>> getFocusSessions();
}
