class NotificationPreference {
  final String id;
  final String userId;
  final String familyId;
  final bool dailySummary;
  final bool instantAlerts;
  final String quietHoursStart;
  final String quietHoursEnd;
  final DateTime updatedAt;

  const NotificationPreference({
    required this.id,
    required this.userId,
    required this.familyId,
    this.dailySummary = true,
    this.instantAlerts = true,
    this.quietHoursStart = '21:00',
    this.quietHoursEnd = '07:00',
    required this.updatedAt,
  });

  factory NotificationPreference.fromJson(Map<String, dynamic> json) {
    return NotificationPreference(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      familyId: json['family_id'] as String,
      dailySummary: json['daily_summary'] as bool? ?? true,
      instantAlerts: json['instant_alerts'] as bool? ?? true,
      quietHoursStart: json['quiet_hours_start'] as String? ?? '21:00',
      quietHoursEnd: json['quiet_hours_end'] as String? ?? '07:00',
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'family_id': familyId,
      'daily_summary': dailySummary,
      'instant_alerts': instantAlerts,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  NotificationPreference copyWith({
    bool? dailySummary,
    bool? instantAlerts,
    String? quietHoursStart,
    String? quietHoursEnd,
    DateTime? updatedAt,
  }) {
    return NotificationPreference(
      id: id,
      userId: userId,
      familyId: familyId,
      dailySummary: dailySummary ?? this.dailySummary,
      instantAlerts: instantAlerts ?? this.instantAlerts,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
