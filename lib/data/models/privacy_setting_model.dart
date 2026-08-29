class PrivacySetting {
  final String id;
  final String familyId;
  final String userId;
  final bool anonymizeData;
  final bool localProcessingOnly;
  final int dataRetentionDays;
  final DateTime updatedAt;

  const PrivacySetting({
    required this.id,
    required this.familyId,
    required this.userId,
    this.anonymizeData = true,
    this.localProcessingOnly = true,
    this.dataRetentionDays = 30,
    required this.updatedAt,
  });

  factory PrivacySetting.fromJson(Map<String, dynamic> json) {
    return PrivacySetting(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      anonymizeData: json['anonymize_data'] as bool? ?? true,
      localProcessingOnly: json['local_processing_only'] as bool? ?? true,
      dataRetentionDays: json['data_retention_days'] as int? ?? 30,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'anonymize_data': anonymizeData,
      'local_processing_only': localProcessingOnly,
      'data_retention_days': dataRetentionDays,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PrivacySetting copyWith({
    bool? anonymizeData,
    bool? localProcessingOnly,
    int? dataRetentionDays,
    DateTime? updatedAt,
  }) {
    return PrivacySetting(
      id: id,
      familyId: familyId,
      userId: userId,
      anonymizeData: anonymizeData ?? this.anonymizeData,
      localProcessingOnly: localProcessingOnly ?? this.localProcessingOnly,
      dataRetentionDays: dataRetentionDays ?? this.dataRetentionDays,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
