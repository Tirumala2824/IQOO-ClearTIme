import 'package:flutter/services.dart';
import '../../../data/models/usage_models.dart';

/// Dart bridge to Android native UsageStatsManager.
class AndroidUsageChannel {
  static const MethodChannel _channel =
      MethodChannel('com.cleartime.cleartime/usage_stats');

  /// Checks if the PACKAGE_USAGE_STATS permission is granted in Android system settings.
  Future<bool> hasUsagePermission() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('hasUsagePermission');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the Android system Usage Access settings screen for the user.
  Future<bool> requestUsagePermission() async {
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('requestUsagePermission');
      return result ?? false;
    } on PlatformException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Fetches aggregated usage data for today.
  Future<Map<String, dynamic>> getTodayUsageData() async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('getTodayUsage');
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (_) {
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Fetches aggregated usage data for a specific time range in millis.
  Future<Map<String, dynamic>> getUsageRange(
      int startTimeMs, int endTimeMs) async {
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'getUsageRange',
        {'startTime': startTimeMs, 'endTime': endTimeMs},
      );
      if (result == null) return {};
      return Map<String, dynamic>.from(result);
    } on PlatformException catch (_) {
      return {};
    } catch (_) {
      return {};
    }
  }

  /// Fetches granular timeline events from Android UsageStatsManager.
  Future<List<UsageTimelineEntry>> getTimeline(
      int startTimeMs, int endTimeMs) async {
    try {
      final List<dynamic>? result =
          await _channel.invokeMethod<List<dynamic>>(
        'getTimeline',
        {'startTime': startTimeMs, 'endTime': endTimeMs},
      );
      if (result == null) return [];

      return result.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return UsageTimelineEntry(
          packageName: map['packageName'] as String? ?? 'unknown',
          appName: map['appName'] as String? ?? 'App',
          category: map['category'] as String? ?? 'General',
          startTime: DateTime.fromMillisecondsSinceEpoch(
              (map['startTime'] as num).toInt()),
          endTime: DateTime.fromMillisecondsSinceEpoch(
              (map['endTime'] as num).toInt()),
          durationMinutes: (map['durationMinutes'] as num? ?? 0).toInt(),
        );
      }).toList();
    } on PlatformException catch (_) {
      return [];
    } catch (_) {
      return [];
    }
  }
}
