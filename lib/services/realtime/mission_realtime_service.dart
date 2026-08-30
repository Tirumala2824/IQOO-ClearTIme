import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services/task_notification_service.dart';
import '../../data/models/mission_model.dart';

/// Live cross-device delivery for activity lifecycle events.
///
/// Subscribes to Supabase Realtime postgres changes on `missions` and
/// `mission_lifecycle_events`. Notifications herein are supplementary taps;
/// the durable event row written by each RPC remains the authoritative
/// delivery record, so an offline device still sees every event on next load.
class MissionRealtimeService {
  final TaskNotificationService _notifications;

  final List<RealtimeChannel> _channels = [];

  MissionRealtimeService({required TaskNotificationService notifications})
      : _notifications = notifications;

  SupabaseClient? get _client {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get _hasSession {
    final client = _client;
    return client != null && client.auth.currentSession != null;
  }

  /// Child device: refresh when the parent creates/reviews an activity.
  RealtimeChannel subscribeToChildMissionChanges({
    required String childProfileId,
    required void Function() onRefresh,
  }) {
    final channel = _subscriptionChannel('child_missions_$childProfileId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'missions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'assigned_to_child_id',
        value: childProfileId,
      ),
      callback: (_) => onRefresh(),
    );

    _subscribe(channel);
    return channel;
  }

  /// Parent device: refresh when the child starts/submits an activity.
  RealtimeChannel subscribeToFamilyMissionChanges({
    required String familyId,
    required void Function() onRefresh,
  }) {
    final channel = _subscriptionChannel('family_missions_$familyId');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'missions',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'family_id',
        value: familyId,
      ),
      callback: (_) => onRefresh(),
    );

    _subscribe(channel);
    return channel;
  }

  /// Own-device event stream. Each recipient event carries only an event id
  /// and type; the notification body is resolved from the local mission so
  /// no child names, task details, or usage ever ride in a payload.
  RealtimeChannel subscribeToLifecycleEvents({
    required void Function(TaskLifecycleEvent event, String missionId) onEvent,
  }) {
    final channel = _subscriptionChannel('my_lifecycle_events');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'mission_lifecycle_events',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'recipient_user_id',
        value: _client?.auth.currentUser?.id ?? '',
      ),
      callback: (payload) {
        final row = payload.newRecord;
        final eventType = _eventFromCode(row['event_type'] as String?);
        final missionId = row['mission_id'] as String?;
        if (eventType == null || missionId == null) {
          return;
        }
        onEvent(eventType, missionId);
      },
    );

    _subscribe(channel);
    return channel;
  }
  RealtimeChannel _subscriptionChannel(String name) {
    final client = _client;
    if (client == null) {
      throw StateError('ClearTime is not connected to a backend.');
    }
    final channel = client.channel('ct_$name');
    _channels.add(channel);
    return channel;
  }

  void _subscribe(RealtimeChannel channel) {
    if (!_hasSession) return;
    channel.subscribe((status, [error]) {
      // Subscription failures are non-fatal: polling + durable events cover it.
    });
  }

  Future<void> dispose() async {
    final client = _client;
    if (client == null) {
      _channels.clear();
      return;
    }
    for (final channel in _channels) {
      await client.removeChannel(channel);
    }
    _channels.clear();
  }

  TaskLifecycleEvent? _eventFromCode(String? code) {
    for (final event in TaskLifecycleEvent.values) {
      if (event.code == code) return event;
    }
    return null;
  }

  /// Resolves a real, transaction-persisted event notification. Returns
  /// false when no mission/recipient context exists locally — delivery of
  /// a fake event is impossible because only the DB writes these rows.
  Future<bool> deliverLifecycleEvent({
    required TaskLifecycleEvent event,
    required String missionId,
    ChildMission? mission,
  }) async {
    switch (event) {
      case TaskLifecycleEvent.newTask:
        if (mission == null) return false;
        return _notifications.notifyNewTask(mission);
      case TaskLifecycleEvent.taskApproved:
        if (mission == null) return false;
        return _notifications.notifyTaskApproved(task: mission);
      case TaskLifecycleEvent.taskNeedsRetry:
        if (mission == null) return false;
        return _notifications.notifyTaskNeedsRetry(
          task: mission,
          parentReason: mission.parentFeedback,
        );
      case TaskLifecycleEvent.taskStarted:
        if (mission == null) return false;
        return _notifications.notifyTaskStarted(mission);
      case TaskLifecycleEvent.taskCompleted:
        if (mission == null) return false;
        return _notifications.notifyTaskCompleted(mission);
      case TaskLifecycleEvent.rewardUnlocked:
        // Unlock notifications are resolved from the reward row itself.
        return false;
    }
  }
}