enum UserRole {
  parent,
  child;

  static UserRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PARENT':
        return UserRole.parent;
      case 'CHILD':
        return UserRole.child;
      default:
        throw ArgumentError('Unknown user role: $value');
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.parent:
        return 'PARENT';
      case UserRole.child:
        return 'CHILD';
    }
  }
}

class UserProfile {
  final String id;
  final String? email;
  final String? phoneNumber;
  final UserRole role;
  final String? displayName;
  final String? avatarUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    this.email,
    this.phoneNumber,
    required this.role,
    this.displayName,
    this.avatarUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isParent => role == UserRole.parent;
  bool get isChild => role == UserRole.child;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String?,
      phoneNumber: json['phone_number'] as String?,
      role: UserRole.fromString(json['role'] as String),
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
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
      'email': email,
      'phone_number': phoneNumber,
      'role': role.toDbString(),
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? displayName,
    String? avatarUrl,
    String? phoneNumber,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      email: email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
