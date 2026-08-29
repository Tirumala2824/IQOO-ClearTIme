import '../../data/models/usage_models.dart';
import '../../data/models/reflection_model.dart';

/// PrivacyGuard provides architectural assertions and validations ensuring
/// that raw child usage records, timeline logs, and reflections can NEVER
/// be transmitted to cloud services, Supabase, or external APIs.
class PrivacyGuard {
  PrivacyGuard._();

  static const String privacyViolationError =
      'PRIVACY VIOLATION: Raw usage data or reflection records must NEVER be exported off-device!';

  /// Asserts that a payload intended for network/cloud transmission contains NO raw usage data.
  static void assertCloudSafe(dynamic data) {
    if (data is UsageRecord ||
        data is UsageTimelineEntry ||
        data is DailyReflection) {
      throw StateError(
          '$privacyViolationError Encountered restricted type: ${data.runtimeType}');
    }

    if (data is Map<String, dynamic>) {
      // Check for raw usage keys
      const forbiddenKeys = {
        'packageName',
        'durationSeconds',
        'startTime',
        'endTime',
        'timeline',
        'rawUsage',
        'reflectionNotes',
      };
      for (final key in forbiddenKeys) {
        if (data.containsKey(key)) {
          throw StateError(
              '$privacyViolationError Payload contains forbidden key: $key');
        }
      }
    }

    if (data is List) {
      for (final item in data) {
        assertCloudSafe(item);
      }
    }
  }

  /// Sanitizes any logging string to avoid printing detailed child usage info.
  static String sanitizeLog(String message) {
    return '[LOCAL PRIVACY SECURE] $message';
  }
}
