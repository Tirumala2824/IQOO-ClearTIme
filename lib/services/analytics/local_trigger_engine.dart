import 'package:uuid/uuid.dart';
import '../../data/models/approved_trigger_event.dart';
import '../../data/models/trigger_config_model.dart';

/// Structured, factual input for local trigger evaluation on the child device.
/// NEVER requires raw package logs or private child AI context.
class TriggerEvaluationInput {
  final String familyId;
  final String childId;
  final int weeklyUsageMinutes;
  final int previousWeeklyUsageMinutes;
  final double usageChangePercent;
  final int focusMinutes;
  final int previousFocusMinutes;
  final double focusChangePercent;
  final double goalProgress; // 0.0 to 100.0
  final int sessionDurationMinutes;
  final int lateNightMinutes;
  final bool positiveTrend;
  final int unlockedAchievementsCount;

  const TriggerEvaluationInput({
    required this.familyId,
    required this.childId,
    this.weeklyUsageMinutes = 0,
    this.previousWeeklyUsageMinutes = 0,
    this.usageChangePercent = 0.0,
    this.focusMinutes = 0,
    this.previousFocusMinutes = 0,
    this.focusChangePercent = 0.0,
    this.goalProgress = 0.0,
    this.sessionDurationMinutes = 0,
    this.lateNightMinutes = 0,
    this.positiveTrend = false,
    this.unlockedAchievementsCount = 0,
  });
}

/// LocalTriggerEngine evaluates configured wellbeing triggers deterministically
/// on the local child device using aggregated analytics facts.
class LocalTriggerEngine {
  final Map<String, DateTime> _cooldownStore = {};
  final Set<String> _processedNotificationIds = {};
  final Uuid _uuid = const Uuid();

  LocalTriggerEngine();

  /// Evaluates whether weekly screen usage increased past the configured threshold (e.g. +20%).
  ApprovedTriggerEvent? evaluateUsageIncrease(
    TriggerEvaluationInput input,
    TriggerConfiguration config, {
    DateTime? now,
  }) {
    if (!config.enabled || config.type != TriggerType.usageIncrease) return null;

    final currentTime = now ?? DateTime.now();
    if (_isCoolingDown(config, currentTime)) return null;

    final changePercent = input.previousWeeklyUsageMinutes > 0
        ? ((input.weeklyUsageMinutes - input.previousWeeklyUsageMinutes) /
                input.previousWeeklyUsageMinutes) *
            100.0
        : input.usageChangePercent;

    if (changePercent >= config.threshold) {
      _recordCooldown(config, currentTime);
      final notifId = _buildDeterministicNotificationId(config, currentTime);

      return ApprovedTriggerEvent(
        id: _uuid.v4(),
        notificationId: notifId,
        familyId: input.familyId,
        childId: input.childId,
        triggerType: TriggerType.usageIncrease,
        threshold: config.threshold,
        observedValue: double.parse(changePercent.toStringAsFixed(1)),
        title: 'Weekly Usage Change',
        message:
            'A weekly screen usage change of +${changePercent.toStringAsFixed(1)}% was detected (configured threshold: ${config.threshold.toInt()}%).',
        timestamp: currentTime,
      );
    }
    return null;
  }

  /// Evaluates whether a continuous single session exceeded the threshold in minutes.
  ApprovedTriggerEvent? evaluateExtendedSession(
    TriggerEvaluationInput input,
    TriggerConfiguration config, {
    DateTime? now,
  }) {
    if (!config.enabled || config.type != TriggerType.extendedSession) return null;

    final currentTime = now ?? DateTime.now();
    if (_isCoolingDown(config, currentTime)) return null;

    if (input.sessionDurationMinutes >= config.threshold) {
      _recordCooldown(config, currentTime);
      final notifId = _buildDeterministicNotificationId(config, currentTime);

      return ApprovedTriggerEvent(
        id: _uuid.v4(),
        notificationId: notifId,
        familyId: input.familyId,
        childId: input.childId,
        triggerType: TriggerType.extendedSession,
        threshold: config.threshold,
        observedValue: input.sessionDurationMinutes.toDouble(),
        title: 'Extended Session Alert',
        message:
            'Continuous active session reached ${input.sessionDurationMinutes} minutes (configured threshold: ${config.threshold.toInt()} min).',
        timestamp: currentTime,
      );
    }
    return null;
  }

  /// Evaluates whether activity occurred during the late-night bedtime window.
  ApprovedTriggerEvent? evaluateLateNightUsage(
    TriggerEvaluationInput input,
    TriggerConfiguration config, {
    DateTime? now,
  }) {
    if (!config.enabled || config.type != TriggerType.lateNightUsage) return null;

    final currentTime = now ?? DateTime.now();
    if (_isCoolingDown(config, currentTime)) return null;

    if (input.lateNightMinutes >= config.threshold) {
      _recordCooldown(config, currentTime);
      final notifId = _buildDeterministicNotificationId(config, currentTime);

      return ApprovedTriggerEvent(
        id: _uuid.v4(),
        notificationId: notifId,
        familyId: input.familyId,
        childId: input.childId,
        triggerType: TriggerType.lateNightUsage,
        threshold: config.threshold,
        observedValue: input.lateNightMinutes.toDouble(),
        title: 'Bedtime Window Activity',
        message:
            'Device activity of ${input.lateNightMinutes} minutes detected in evening bedtime window.',
        timestamp: currentTime,
      );
    }
    return null;
  }

  /// Evaluates whether goal progress achieved or surpassed completion threshold.
  ApprovedTriggerEvent? evaluateGoalCompletion(
    TriggerEvaluationInput input,
    TriggerConfiguration config, {
    DateTime? now,
  }) {
    if (!config.enabled || config.type != TriggerType.goalCompletion) return null;

    final currentTime = now ?? DateTime.now();
    if (_isCoolingDown(config, currentTime)) return null;

    if (input.goalProgress >= config.threshold) {
      _recordCooldown(config, currentTime);
      final notifId = _buildDeterministicNotificationId(config, currentTime);

      return ApprovedTriggerEvent(
        id: _uuid.v4(),
        notificationId: notifId,
        familyId: input.familyId,
        childId: input.childId,
        triggerType: TriggerType.goalCompletion,
        threshold: config.threshold,
        observedValue: input.goalProgress,
        title: 'Focus Goal Completed',
        message:
            'Mindful wellbeing goal completed! Progress reached ${input.goalProgress.toInt()}%.',
        timestamp: currentTime,
      );
    }
    return null;
  }

  /// Evaluates whether focused learning time improved between comparative periods.
  ApprovedTriggerEvent? evaluateFocusImprovement(
    TriggerEvaluationInput input,
    TriggerConfiguration config, {
    DateTime? now,
  }) {
    if (!config.enabled || config.type != TriggerType.focusImprovement) return null;

    final currentTime = now ?? DateTime.now();
    if (_isCoolingDown(config, currentTime)) return null;

    final focusChange = input.previousFocusMinutes > 0
        ? ((input.focusMinutes - input.previousFocusMinutes) /
                input.previousFocusMinutes) *
            100.0
        : input.focusChangePercent;

    if (focusChange >= config.threshold) {
      _recordCooldown(config, currentTime);
      final notifId = _buildDeterministicNotificationId(config, currentTime);

      return ApprovedTriggerEvent(
        id: _uuid.v4(),
        notificationId: notifId,
        familyId: input.familyId,
        childId: input.childId,
        triggerType: TriggerType.focusImprovement,
        threshold: config.threshold,
        observedValue: double.parse(focusChange.toStringAsFixed(1)),
        title: 'Focus Time Growth',
        message:
            'Focus and learning time improved by +${focusChange.toStringAsFixed(1)}%.',
        timestamp: currentTime,
      );
    }
    return null;
  }

  /// Evaluates whether positive wellbeing balance trend was maintained.
  ApprovedTriggerEvent? evaluatePositiveTrend(
    TriggerEvaluationInput input,
    TriggerConfiguration config, {
    DateTime? now,
  }) {
    if (!config.enabled || config.type != TriggerType.positiveTrend) return null;

    final currentTime = now ?? DateTime.now();
    if (_isCoolingDown(config, currentTime)) return null;

    if (input.positiveTrend) {
      _recordCooldown(config, currentTime);
      final notifId = _buildDeterministicNotificationId(config, currentTime);

      return ApprovedTriggerEvent(
        id: _uuid.v4(),
        notificationId: notifId,
        familyId: input.familyId,
        childId: input.childId,
        triggerType: TriggerType.positiveTrend,
        threshold: config.threshold,
        observedValue: 100.0,
        title: 'Positive Wellbeing Trend',
        message:
            'Consistent positive balance detected across weekly wellbeing intervals.',
        timestamp: currentTime,
      );
    }
    return null;
  }

  /// Evaluates all active configurations against local analytics facts.
  List<ApprovedTriggerEvent> evaluateAll({
    required TriggerEvaluationInput input,
    required List<TriggerConfiguration> configs,
    DateTime? now,
  }) {
    final results = <ApprovedTriggerEvent>[];
    final currentTime = now ?? DateTime.now();

    for (final config in configs) {
      if (!config.enabled) continue;
      // Isolate by childId if configured
      if (config.childId.isNotEmpty && config.childId != input.childId) {
        continue;
      }

      ApprovedTriggerEvent? event;
      switch (config.type) {
        case TriggerType.usageIncrease:
          event = evaluateUsageIncrease(input, config, now: currentTime);
          break;
        case TriggerType.extendedSession:
          event = evaluateExtendedSession(input, config, now: currentTime);
          break;
        case TriggerType.lateNightUsage:
          event = evaluateLateNightUsage(input, config, now: currentTime);
          break;
        case TriggerType.goalCompletion:
          event = evaluateGoalCompletion(input, config, now: currentTime);
          break;
        case TriggerType.focusImprovement:
          event = evaluateFocusImprovement(input, config, now: currentTime);
          break;
        case TriggerType.positiveTrend:
          event = evaluatePositiveTrend(input, config, now: currentTime);
          break;
      }

      if (event != null) {
        // Idempotency filter
        if (!_processedNotificationIds.contains(event.notificationId)) {
          _processedNotificationIds.add(event.notificationId);
          results.add(event);
        }
      }
    }

    return results;
  }

  bool _isCoolingDown(TriggerConfiguration config, DateTime now) {
    final key = '${config.id.isNotEmpty ? config.id : config.type.name}_${config.childId}';
    final lastFired = _cooldownStore[key];
    if (lastFired == null) return false;
    return now.difference(lastFired) < config.cooldown;
  }

  void _recordCooldown(TriggerConfiguration config, DateTime now) {
    final key = '${config.id.isNotEmpty ? config.id : config.type.name}_${config.childId}';
    _cooldownStore[key] = now;
  }

  String _buildDeterministicNotificationId(TriggerConfiguration config, DateTime now) {
    final dateKey = '${now.year}-${now.month}-${now.day}';
    return 'notif_${config.type.name}_${config.childId}_$dateKey';
  }

  /// Clears local cooldowns and idempotency history (e.g. on test teardown or local reset).
  void clearState() {
    _cooldownStore.clear();
    _processedNotificationIds.clear();
  }
}
