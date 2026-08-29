import 'dart:async';
import 'package:flutter/services.dart';
import '../../../data/models/trigger_config_model.dart';
import '../../services/abstractions/notification_provider.dart';

/// Native Notification Bridge backed by Android NotificationManager and MethodChannel.
/// Implements automatic spam protection, cooldowns, and deduplication.
class NativeNotificationBridge implements NotificationProvider {
  static const MethodChannel _channel =
      MethodChannel('com.cleartime.cleartime/notifications');

  // In-memory cache for spam protection & deduplication
  final Map<String, DateTime> _recentNotificationCache = {};
  static const Duration _duplicateCooldown = Duration(minutes: 5);

  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
    } catch (_) {
      // Fallback gracefully in testing environments
      _isInitialized = true;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('hasPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final res = await _channel.invokeMethod<bool>('requestPermission');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? payload,
    NotificationType notificationType = NotificationType.push,
  }) async {
    if (notificationType == NotificationType.silentReport) return;

    // Spam Protection: Deduplication Check
    final dedupeKey = '$id:$title:$body';
    final lastSent = _recentNotificationCache[dedupeKey];
    final now = DateTime.now();

    if (lastSent != null && now.difference(lastSent) < _duplicateCooldown) {
      return; // Suppress duplicate spam
    }

    _recentNotificationCache[dedupeKey] = now;

    try {
      await _channel.invokeMethod('showNotification', {
        'id': id,
        'title': title,
        'body': body,
        'channelId': channelId ?? 'cleartime_general',
        'payload': payload,
      });
    } catch (_) {
      // Graceful fallback
    }
  }

  @override
  Future<void> showChildWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      id: id,
      title: title,
      body: body,
      channelId: 'cleartime_child_wellbeing',
      payload: payload,
    );
  }

  @override
  Future<void> showParentAlertNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await showNotification(
      id: id,
      title: title,
      body: body,
      channelId: 'cleartime_parent_alerts',
      payload: payload,
    );
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? channelId,
    String? payload,
  }) async {
    try {
      await _channel.invokeMethod('scheduleNotification', {
        'id': id,
        'title': title,
        'body': body,
        'timestamp': scheduledTime.millisecondsSinceEpoch,
        'channelId': channelId ?? 'cleartime_reports',
        'payload': payload,
      });
    } catch (_) {
      // Graceful fallback
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      await _channel.invokeMethod('cancelNotification', {'id': id});
    } catch (_) {}
  }

  @override
  Future<void> cancelAllNotifications() async {
    _recentNotificationCache.clear();
    try {
      await _channel.invokeMethod('cancelAllNotifications');
    } catch (_) {}
  }

  /// Clears in-memory spam protection cache for testing.
  void clearSpamCache() {
    _recentNotificationCache.clear();
  }
}
