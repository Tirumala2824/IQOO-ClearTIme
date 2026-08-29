/// Abstract interface for local and system notifications.
abstract class NotificationProvider {
  /// Initializes notification channels and platform handlers.
  Future<void> initialize();

  /// Checks notification permissions.
  Future<bool> hasPermission();

  /// Requests notification permissions.
  Future<bool> requestPermission();

  /// Shows a gentle, encouraging local wellbeing notification.
  Future<void> showWellbeingNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Cancels a scheduled or active notification.
  Future<void> cancelNotification(int id);
}
