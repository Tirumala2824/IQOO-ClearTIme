import 'trigger_config_model.dart';

/// Minimal, privacy-safe approved trigger event structure for remote notification dispatch.
/// CRITICAL: Contains ZERO raw app names, package names, raw timeline sessions, or private AI reflections.
class ApprovedTriggerEvent {
  final String id;
  final String eventType; // Constant: "WELLBEING_ALERT"
  final String notificationId;
  final String familyId;
  final String childId;
  final TriggerType triggerType;
  final double threshold;
  final double observedValue;
  final String title;
  final String message;
  final DateTime timestamp;

  const ApprovedTriggerEvent({
    required this.id,
    this.eventType = 'WELLBEING_ALERT',
    required this.notificationId,
    required this.familyId,
    required this.childId,
    required this.triggerType,
    required this.threshold,
    required this.observedValue,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  factory ApprovedTriggerEvent.fromJson(Map<String, dynamic> json) {
    return ApprovedTriggerEvent(
      id: json['id'] as String? ?? json['notification_id'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'WELLBEING_ALERT',
      notificationId: json['notification_id'] as String? ?? '',
      familyId: json['family_id'] as String? ?? '',
      childId: json['child_id'] as String? ?? '',
      triggerType: TriggerType.values
              .where((t) => t.name == json['trigger_type'])
              .firstOrNull ??
          TriggerType.usageIncrease,
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0.0,
      observedValue: (json['observed_value'] as num?)?.toDouble() ?? 0.0,
      title: json['title'] as String? ?? 'Wellbeing Notification',
      message: json['message'] as String? ?? 'A configured wellbeing event was observed.',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_type': eventType,
      'notification_id': notificationId,
      'family_id': familyId,
      'child_id': childId,
      'trigger_type': triggerType.name,
      'threshold': threshold,
      'observed_value': observedValue,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
