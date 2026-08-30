import '../../../data/models/usage_models.dart';

/// The current state of device usage access.
///
/// Callers must render one of these states truthfully instead of treating the
/// absence of access as zero usage.
enum UsageAccessState {
  /// Permission granted and an authorized usage API is available.
  ready,
  /// Android Usage Access is not granted yet; ask only from an intentional
  /// setup screen.
  permissionNeeded,
  /// The platform has no authorized activity API (iOS/web/desktop).
  unsupported,
  /// Access exists but reading real data failed on this attempt.
  collectionFailed,
}

/// Raised when a caller attempts to read usage data while access is not ready.
class UsageAccessStateException implements Exception {
  final UsageAccessState state;
  const UsageAccessStateException(this.state);

  @override
  String toString() => 'Usage access is not available: ${state.name}.';
}

/// Raised when the operating system has not granted access to real device
/// activity.
class UsageAccessRequiredException extends UsageAccessStateException {
  const UsageAccessRequiredException() : super(UsageAccessState.permissionNeeded);
}

/// Raised when the platform has no equivalent authorized activity API.
class UsageUnsupportedException extends UsageAccessStateException {
  const UsageUnsupportedException() : super(UsageAccessState.unsupported);
}

/// Raised when usage collection itself failed (e.g. native bridge error).
class UsageCollectionFailedException extends UsageAccessStateException {
  const UsageCollectionFailedException() : super(UsageAccessState.collectionFailed);
}

/// Abstract definition for on-device local usage data collection.
///
/// CRITICAL PRIVACY RULE:
/// Raw application usage and granular timestamps NEVER leave the device.
/// No raw usage data is ever sent to Supabase or cloud telemetry.
abstract class UsageDataProvider {
  /// The current access state for this device.
  Future<UsageAccessState> getUsageAccessState();

  /// Checks whether local usage access permissions are granted on the Android device.
  Future<bool> hasUsagePermission();

  /// Opens the Android system Usage Access settings screen for the user.
  /// Must only be invoked from an intentional setup/action screen.
  Future<bool> requestUsagePermission();

  /// Fetches aggregated usage summary for today. Throws
  /// [UsageAccessStateException] instead of returning zeroes when access is
  /// not ready or collection fails.
  Future<UsageSummary> getTodayUsage();

  /// Fetches a daily breakdown for the requested number of recent days,
  /// computed from collected local aggregates.
  Future<List<DailyUsage>> getDailyUsage();

  /// Fetches weekly usage breakdown for the past 7 days.
  Future<List<DailyUsage>> getWeeklyUsage();

  /// Fetches monthly usage breakdown for the past 30 days.
  Future<List<DailyUsage>> getMonthlyUsage();

  /// Fetches category breakdown of app usage.
  Future<List<CategoryUsage>> getCategoryUsage();

  /// Fetches the local usage timeline entries.
  Future<List<UsageTimelineEntry>> getUsageTimeline();

  /// Fetches recorded focus sessions.
  Future<List<FocusSession>> getFocusSessions();
}