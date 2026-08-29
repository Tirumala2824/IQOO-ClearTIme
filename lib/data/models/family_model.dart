class Family {
  final String id;
  final String name;
  final String adminUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Family({
    required this.id,
    required this.name,
    required this.adminUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Family.fromJson(Map<String, dynamic> json) {
    return Family(
      id: json['id'] as String,
      name: json['name'] as String,
      adminUserId: json['admin_user_id'] as String,
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
      'name': name,
      'admin_user_id': adminUserId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
