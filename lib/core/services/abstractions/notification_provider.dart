import '../../../data/models/trigger_config_model.dart';

/// Abstract interface for local and system notifications.
abstract class NotificationProvider {
  /// Initializes notification channels and platform handlers.
  Future<void> initialize();

  /// Checks notification permissions.
  Future<bool> hasPermission();

  /// Requests notification permissions.
  Future<bool> requestPermission();

  /// Shows a general notification.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? channelId,
    String? payload,
    NotificationType notificationType = NotificationType.push,
  });

  /// Shows a gentle, encouraging wellbeing notification for the child.
  /// (e.g. focus missions, break reminders, goal completion, achievements)
  Future<void> showChildWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Shows a privacy-safe wellbeing alert for the parent.
  /// (e.g. approved weekly reports ready, configured wellbeing changes)
  Future<void> showParentAlertNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Schedules a future notification.
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? channelId,
    String? payload,
  });

  /// Cancels a scheduled or active notification.
  Future<void> cancelNotification(int id);

  /// Cancels all active notifications.
  Future<void> cancelAllNotifications();
}
