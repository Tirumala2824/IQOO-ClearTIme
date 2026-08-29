enum ReportFrequency {
  daily,
  weekly,
  monthly;

  static ReportFrequency fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DAILY':
        return ReportFrequency.daily;
      case 'WEEKLY':
        return ReportFrequency.weekly;
      case 'MONTHLY':
        return ReportFrequency.monthly;
      default:
        return ReportFrequency.weekly;
    }
  }

  String toDbString() {
    switch (this) {
      case ReportFrequency.daily:
        return 'DAILY';
      case ReportFrequency.weekly:
        return 'WEEKLY';
      case ReportFrequency.monthly:
        return 'MONTHLY';
    }
  }
}

enum DeliveryChannel {
  inApp,
  email;

  static DeliveryChannel fromString(String value) {
    switch (value.toUpperCase()) {
      case 'IN_APP':
        return DeliveryChannel.inApp;
      case 'EMAIL':
        return DeliveryChannel.email;
      default:
        return DeliveryChannel.inApp;
    }
  }

  String toDbString() {
    switch (this) {
      case DeliveryChannel.inApp:
        return 'IN_APP';
      case DeliveryChannel.email:
        return 'EMAIL';
    }
  }
}

class ReportConfiguration {
  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final ReportFrequency frequency;
  final DeliveryChannel deliveryChannel;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReportConfiguration({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.title,
    this.frequency = ReportFrequency.weekly,
    this.deliveryChannel = DeliveryChannel.inApp,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportConfiguration.fromJson(Map<String, dynamic> json) {
    return ReportConfiguration(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      frequency:
          ReportFrequency.fromString(json['frequency'] as String? ?? 'WEEKLY'),
      deliveryChannel: DeliveryChannel.fromString(
          json['delivery_channel'] as String? ?? 'IN_APP'),
      isEnabled: json['is_enabled'] as bool? ?? true,
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
      'title': title,
      'frequency': frequency.toDbString(),
      'delivery_channel': deliveryChannel.toDbString(),
      'is_enabled': isEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ReportConfiguration copyWith({
    String? title,
    ReportFrequency? frequency,
    DeliveryChannel? deliveryChannel,
    bool? isEnabled,
    DateTime? updatedAt,
  }) {
    return ReportConfiguration(
      id: id,
      familyId: familyId,
      createdBy: createdBy,
      title: title ?? this.title,
      frequency: frequency ?? this.frequency,
      deliveryChannel: deliveryChannel ?? this.deliveryChannel,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
