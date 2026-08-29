enum FamilyRole {
  admin,
  member;

  static FamilyRole fromString(String value) {
    switch (value.toUpperCase()) {
      case 'ADMIN':
        return FamilyRole.admin;
      case 'MEMBER':
        return FamilyRole.member;
      default:
        return FamilyRole.member;
    }
  }

  String toDbString() {
    switch (this) {
      case FamilyRole.admin:
        return 'ADMIN';
      case FamilyRole.member:
        return 'MEMBER';
    }
  }
}

class FamilyMember {
  final String id;
  final String familyId;
  final String userId;
  final FamilyRole role;
  final DateTime joinedAt;

  const FamilyMember({
    required this.id,
    required this.familyId,
    required this.userId,
    this.role = FamilyRole.member,
    required this.joinedAt,
  });

  bool get isAdmin => role == FamilyRole.admin;

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    return FamilyMember(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      userId: json['user_id'] as String,
      role: FamilyRole.fromString(json['role'] as String? ?? 'MEMBER'),
      joinedAt: json['joined_at'] != null
          ? DateTime.parse(json['joined_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'family_id': familyId,
      'user_id': userId,
      'role': role.toDbString(),
      'joined_at': joinedAt.toIso8601String(),
    };
  }
}
