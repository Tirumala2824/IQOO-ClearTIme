import '../../../data/models/mission_model.dart';
import '../../../data/models/reward_model.dart';
import 'abstractions/notification_provider.dart';

/// Lifecycle events emitted by the real-world task system.
///
/// Every event is generated from an actual application action performed on
/// real persisted state. No notification is ever created for demonstration.
enum TaskLifecycleEvent {
  newTask('NEW_TASK'),
  taskStarted('TASK_STARTED'),
  taskCompleted('TASK_COMPLETED'),
  taskApproved('TASK_APPROVED'),
  taskNeedsRetry('TASK_NEEDS_RETRY'),
  rewardUnlocked('REWARD_UNLOCKED');

  const TaskLifecycleEvent(this.code);
  final String code;
}

/// Delivers task lifecycle notifications through the existing notification
/// bridge. This is not an independent delivery system: it reuses the
/// [NotificationProvider] abstraction, its channels, dedup and throttling.
class TaskNotificationService {
  final NotificationProvider _notificationProvider;

  TaskNotificationService({required NotificationProvider notificationProvider})
      : _notificationProvider = notificationProvider;

  NotificationProvider get notificationProvider => _notificationProvider;

  int _idFor(TaskLifecycleEvent event, String taskId) =>
      ('task-${event.code}-$taskId').hashCode.abs();

  /// [NEW_TASK] — child notification for a newly assigned real task.
  Future<bool> notifyNewTask(ChildMission task) async {
    final rewardLine =
        (task.reward != null && task.reward!.trim().isNotEmpty)
            ? ' Reward: ${task.reward}.'
            : '';
    return _safeShow(
      event: TaskLifecycleEvent.newTask,
      taskId: task.id,
      childFacing: true,
      title: 'New Mission! 🎯',
      body: '"${task.title}" is waiting for you.$rewardLine',
    );
  }

  /// [TASK_STARTED] — parent notification when the child actually starts.
  Future<bool> notifyTaskStarted(ChildMission task) async {
    final child = task.assignedToChildNickname ?? 'Your child';
    return _safeShow(
      event: TaskLifecycleEvent.taskStarted,
      taskId: task.id,
      childFacing: false,
      title: 'Task Started 🚀',
      body:
          '$child started "${task.title}" (${task.targetMinutes} min activity).',
    );
  }

  /// [TASK_COMPLETED] — parent notification after a real submission.
  Future<bool> notifyTaskCompleted(ChildMission task) async {
    final child = task.assignedToChildNickname ?? 'Your child';
    return _safeShow(
      event: TaskLifecycleEvent.taskCompleted,
      taskId: task.id,
      childFacing: false,
      title: 'Task Completed ✅',
      body:
          '$child completed "${task.title}". It is ready for your review.',
    );
  }

  /// [TASK_APPROVED] — child notification after real parent approval.
  /// The reward line appears only when an actual reward exists and was
  /// actually unlocked. Never claims a reward when none exists.
  Future<bool> notifyTaskApproved({
    required ChildMission task,
    Reward? unlockedReward,
  }) async {
    final hasUnlockedReward =
        unlockedReward != null && unlockedReward.status == RewardStatus.unlocked;
    final body = hasUnlockedReward
        ? '"${task.title}" was approved. Your reward "${unlockedReward.title}" is unlocked — enjoy it together! 🎉'
        : '"${task.title}" was approved. Great effort! 🌟';
    return _safeShow(
      event: TaskLifecycleEvent.taskApproved,
      taskId: task.id,
      childFacing: true,
      title: hasUnlockedReward ? 'Mission Approved! 🌟' : 'Mission Approved! 🌟',
      body: body,
    );
  }

  /// [TASK_NEEDS_RETRY] — encouraging child notification for another attempt.
  /// Uses only a parent-provided reason when one was actually given.
  Future<bool> notifyTaskNeedsRetry({
    required ChildMission task,
    String? parentReason,
  }) async {
    final reasonLine = (parentReason != null && parentReason.trim().isNotEmpty)
        ? ' Note from your parent: ${parentReason.trim()}'
        : '';
    return _safeShow(
      event: TaskLifecycleEvent.taskNeedsRetry,
      taskId: task.id,
      childFacing: true,
      title: 'Almost there! 💪',
      body:
          'Nice effort on "${task.title}". One more try — you\'re making progress!$reasonLine',
    );
  }

  /// [REWARD_UNLOCKED] — child notification when a real reward unlocks.
  Future<bool> notifyRewardUnlocked({
    required Reward reward,
    required String childNickname,
  }) async {
    return _safeShow(
      event: TaskLifecycleEvent.rewardUnlocked,
      taskId: reward.taskId,
      childFacing: true,
      title: 'Reward Unlocked! 🎁',
      body:
          '$childNickname, "${reward.title}" is unlocked. Enjoy it together!',
    );
  }

  /// Delivery failures are surfaced to the caller via [notifyFailure] rather
  /// than silently swallowed: never claim success when delivery failed.
  Future<bool> _safeShow({
    required TaskLifecycleEvent event,
    required String taskId,
    required bool childFacing,
    required String title,
    required String body,
  }) async {
    try {
      if (childFacing) {
        await _notificationProvider.showChildWellbeingNotification(
          id: _idFor(event, taskId),
          title: title,
          body: body,
          payload: event.code,
        );
      } else {
        await _notificationProvider.showParentAlertNotification(
          id: _idFor(event, taskId),
          title: title,
          body: body,
          payload: event.code,
        );
      }
      return true;
    } catch (_) {
      // Do not fabricate success. Callers record the failure via the
      // returned result; persisted lifecycle state remains authoritative.
      return false;
    }
  }
}
