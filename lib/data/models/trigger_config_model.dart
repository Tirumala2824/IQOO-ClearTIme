enum TriggerType {
  usageIncrease,
  extendedSession,
  lateNightUsage,
  goalCompletion,
  focusImprovement,
  positiveTrend,
}

extension TriggerTypeExtension on TriggerType {
  String get label {
    switch (this) {
      case TriggerType.usageIncrease:
        return 'Usage Increase';
      case TriggerType.extendedSession:
        return 'Extended Session';
      case TriggerType.lateNightUsage:
        return 'Late-Night Usage';
      case TriggerType.goalCompletion:
        return 'Goal Completion';
      case TriggerType.focusImprovement:
        return 'Focus Improvement';
      case TriggerType.positiveTrend:
        return 'Positive Trend';
    }
  }

  String get defaultDescription {
    switch (this) {
      case TriggerType.usageIncrease:
        return 'Notifies when weekly screen usage increases beyond threshold percentage';
      case TriggerType.extendedSession:
        return 'Notifies when continuous single session exceeds configured minutes';
      case TriggerType.lateNightUsage:
        return 'Notifies when device activity is detected in evening bedtime window';
      case TriggerType.goalCompletion:
        return 'Celebrates when daily/weekly focus goals reach completion threshold';
      case TriggerType.focusImprovement:
        return 'Highlights positive growth in concentrated focus intervals';
      case TriggerType.positiveTrend:
        return 'Celebrates consistent mindful balance over weekly periods';
    }
  }

  String get unit {
    switch (this) {
      case TriggerType.usageIncrease:
        return '%';
      case TriggerType.extendedSession:
        return 'min';
      case TriggerType.lateNightUsage:
        return 'min';
      case TriggerType.goalCompletion:
        return '%';
      case TriggerType.focusImprovement:
        return '%';
      case TriggerType.positiveTrend:
        return '%';
    }
  }
}

enum NotificationType {
  push,
  inApp,
  silentReport,
}

class TriggerConfiguration {
  final String id;
  final String familyId;
  final String childId;
  final TriggerType type;
  final double threshold;
  final bool enabled;
  final Duration cooldown;
  final NotificationType notificationType;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Optional alias / legacy compatibility fields
  final String? customName;

  const TriggerConfiguration({
    required this.id,
    required this.familyId,
    required this.childId,
    required this.type,
    required this.threshold,
    this.enabled = true,
    this.cooldown = const Duration(hours: 24),
    this.notificationType = NotificationType.push,
    required this.createdAt,
    required this.updatedAt,
    this.customName,
  });

  // Convenience getters
  String get name => customName ?? type.label;
  bool get isActive => enabled;
  int get thresholdMinutes => threshold.toInt();
  String get triggerType => type.name;

  factory TriggerConfiguration.fromJson(Map<String, dynamic> json) {
    // Parse trigger type
    TriggerType parsedType = TriggerType.usageIncrease;
    final typeStr = json['type'] ?? json['trigger_type'];
    if (typeStr != null) {
      for (final t in TriggerType.values) {
        if (t.name.toLowerCase() == typeStr.toString().toLowerCase() ||
            typeStr.toString().toLowerCase().contains(t.name.toLowerCase())) {
          parsedType = t;
          break;
        }
      }
      // Handle legacy string mappings
      if (typeStr == 'SCREEN_TIME_LIMIT') parsedType = TriggerType.extendedSession;
      if (typeStr == 'BEDTIME_WINDOW') parsedType = TriggerType.lateNightUsage;
      if (typeStr == 'FOCUS_SESSION') parsedType = TriggerType.focusImprovement;
    }

    // Parse notification type
    NotificationType parsedNotif = NotificationType.push;
    final notifStr = json['notification_type'] ?? json['notificationType'];
    if (notifStr != null) {
      for (final n in NotificationType.values) {
        if (n.name.toLowerCase() == notifStr.toString().toLowerCase()) {
          parsedNotif = n;
          break;
        }
      }
    }

    // Parse cooldown in seconds
    final cooldownSeconds = json['cooldown_seconds'] as int? ??
        (json['cooldown'] != null ? json['cooldown'] as int : 86400);

    return TriggerConfiguration(
      id: json['id'] as String? ?? '',
      familyId: json['family_id'] as String? ?? json['familyId'] as String? ?? '',
      childId: json['child_id'] as String? ?? json['childId'] as String? ?? '',
      type: parsedType,
      threshold: (json['threshold'] as num?)?.toDouble() ??
          (json['threshold_minutes'] as num?)?.toDouble() ??
          20.0,
      enabled: json['enabled'] as bool? ?? json['is_active'] as bool? ?? true,
      cooldown: Duration(seconds: cooldownSeconds),
      notificationType: parsedNotif,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      customName: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'child_id': childId,
      'type': type.name,
      'threshold': threshold,
      'enabled': enabled,
      'cooldown_seconds': cooldown.inSeconds,
      'notification_type': notificationType.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'name': name,
    };
  }

  TriggerConfiguration copyWith({
    String? id,
    String? familyId,
    String? childId,
    TriggerType? type,
    double? threshold,
    bool? enabled,
    Duration? cooldown,
    NotificationType? notificationType,
    DateTime? updatedAt,
    String? customName,
  }) {
    return TriggerConfiguration(
      id: id ?? this.id,
      familyId: familyId ?? this.familyId,
      childId: childId ?? this.childId,
      type: type ?? this.type,
      threshold: threshold ?? this.threshold,
      enabled: enabled ?? this.enabled,
      cooldown: cooldown ?? this.cooldown,
      notificationType: notificationType ?? this.notificationType,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      customName: customName ?? this.customName,
    );
  }
}
