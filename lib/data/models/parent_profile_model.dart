class ParentProfile {
  final String id;
  final String userId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ParentProfile({
    required this.id,
    required this.userId,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ParentProfile.fromJson(Map<String, dynamic> json) {
    return ParentProfile(
      id: json['id'] as String,
      userId: json['user_id'] as String,
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
      'user_id': userId,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
