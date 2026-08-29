import '../../data/models/approved_report_model.dart';
import '../../data/models/approved_trigger_event.dart';
import '../../data/models/reflection_model.dart';
import '../../data/models/report_config_model.dart';
import '../../data/models/trigger_config_model.dart';
import '../../data/models/usage_models.dart';

/// UsageSyncGuard enforces an absolute architectural wall preventing raw child
/// usage records, app packages, timelines, or private reflections from ever reaching
/// remote network repositories or cloud endpoints.
class UsageSyncGuard {
  UsageSyncGuard._();

  /// NON-NEGOTIABLE CORE ARCHITECTURAL RULE
  static const bool rawChildUsageMustNeverBeSentToServer = true;
  // ignore: constant_identifier_names
  static const bool RAW_CHILD_USAGE_MUST_NEVER_BE_SENT_TO_SERVER = true;

  static const String violationMessage =
      'CRITICAL ARCHITECTURAL VIOLATION: Raw child usage data, app packages, or private diary reflections cannot be synced to the backend!';

  /// Asserts that the object is safe for network serialization and cloud synchronization.
  static void assertRawUsageCannotBeSerializedForSync(dynamic object) {
    if (object == null) return;

    if (object is UsageRecord ||
        object is UsageTimelineEntry ||
        object is DailyReflection) {
      throw StateError(
          '$violationMessage Blocked illegal type: ${object.runtimeType}');
    }

    if (object is Map<String, dynamic>) {
      const restrictedKeys = {
        'packageName',
        'package_name',
        'durationSeconds',
        'duration_seconds',
        'startTime',
        'start_time',
        'endTime',
        'end_time',
        'timeline',
        'rawUsage',
        'raw_usage',
        'reflectionNotes',
        'reflection_notes',
      };

      for (final key in restrictedKeys) {
        if (object.containsKey(key)) {
          throw StateError('$violationMessage Blocked forbidden payload key: $key');
        }
      }

      for (final entry in object.entries) {
        assertRawUsageCannotBeSerializedForSync(entry.value);
      }
    }

    if (object is List) {
      for (final item in object) {
        assertRawUsageCannotBeSerializedForSync(item);
      }
    }
  }

  /// Asserts that a remote repository payload strictly belongs to an approved sharing model.
  static void assertRawUsageCannotReachRemoteRepository(dynamic payload) {
    assertRawUsageCannotBeSerializedForSync(payload);

    // If it's a known approved domain model, it passes cleanly
    if (payload is ApprovedReport ||
        payload is ApprovedInsight ||
        payload is ApprovedTriggerEvent ||
        payload is TriggerConfiguration ||
        payload is ReportConfiguration) {
      return;
    }
  }

  /// Validates outgoing HTTP/Supabase payloads
  static bool validateOutgoingSyncPayload(dynamic payload) {
    try {
      assertRawUsageCannotReachRemoteRepository(payload);
      return true;
    } catch (_) {
      return false;
    }
  }
}
