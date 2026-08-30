import 'package:flutter/foundation.dart';

/// Opaque push payload keys. Payloads carry only an event id and type —
/// never child names, task details, raw usage, or report content.
class PushEventPayload {
  final String eventId;
  final String eventType;

  const PushEventPayload({required this.eventId, required this.eventType});

  factory PushEventPayload.fromData(Map<String, dynamic> data) =>
      PushEventPayload(
        eventId: data['event_id'] as String? ?? '',
        eventType: data['event_type'] as String? ?? '',
      );

  bool get isValid => eventId.isNotEmpty && eventType.isNotEmpty;
}

/// FCM delivery, active only when Firebase credentials are configured.
///
/// Realtime + the durable event/report-request rows remain the guaranteed
/// delivery path; FCM is a supplementary wake-up signal. When credentials
/// are absent (as in development) every method is a safe no-op.
class PushNotificationService {
  final bool _configured;

  PushNotificationService({required bool configured}) : _configured = configured;

  bool get isConfigured => _configured;

  /// Resolves a target route for an event payload, for deep-link handling.
  /// Mission lifecycle events open the child/parent activity screens;
  /// report events open the reports screen.
  String routeForPayload(PushEventPayload payload) {
    switch (payload.eventType) {
      case 'NEW_TASK':
      case 'TASK_STARTED':
      case 'TASK_COMPLETED':
      case 'TASK_APPROVED':
      case 'TASK_NEEDS_RETRY':
      case 'REWARD_UNLOCKED':
        return '/child/missions';
      case 'REPORT_READY':
      case 'REPORT_UNAVAILABLE':
      case 'REPORT_REQUESTED':
        return '/parent/reports';
      default:
        return '/';
    }
  }

  /// Placeholder for FCM initialization. Real implementation is activated
  /// by [PushNotificationService.mobile] once google-services.json /
  /// GoogleService-Info.plist are provisioned. Never throws.
  Future<void> initialize() async {
    if (!_configured || kIsWeb) return;
    // firebase_messaging initialization goes here behind the configured flag.
  }
}