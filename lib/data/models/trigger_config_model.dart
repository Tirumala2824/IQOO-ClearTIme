class TriggerConfiguration {
  final String id;
  final String familyId;
  final String createdBy;
  final String name;
  final String triggerType;
  final int thresholdMinutes;
  final String action;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TriggerConfiguration({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.name,
    required this.triggerType,
    required this.thresholdMinutes,
    this.action = 'NOTIFY_PARENT',
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TriggerConfiguration.fromJson(Map<String, dynamic> json) {
    return TriggerConfiguration(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      name: json['name'] as String,
      triggerType: json['trigger_type'] as String,
      thresholdMinutes: json['threshold_minutes'] as int? ?? 60,
      action: json['action'] as String? ?? 'NOTIFY_PARENT',
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'created_by': createdBy,
      'name': name,
      'trigger_type': triggerType,
      'threshold_minutes': thresholdMinutes,
      'action': action,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  TriggerConfiguration copyWith({
    String? name,
    String? triggerType,
    int? thresholdMinutes,
    String? action,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return TriggerConfiguration(
      id: id,
      familyId: familyId,
      createdBy: createdBy,
      name: name ?? this.name,
      triggerType: triggerType ?? this.triggerType,
      thresholdMinutes: thresholdMinutes ?? this.thresholdMinutes,
      action: action ?? this.action,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
