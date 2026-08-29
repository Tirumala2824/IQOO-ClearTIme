class ChildProfile {
  final String id;
  final String userId;
  final String familyId;
  final String nickname;
  final int? age;
  final int avatarIndex;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ChildProfile({
    required this.id,
    this.userId = '',
    this.familyId = '',
    required this.nickname,
    this.age,
    this.avatarIndex = 0,
    this.createdAt,
    this.updatedAt,
  });

  DateTime get creationDate => createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  DateTime get updateDate => updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  factory ChildProfile.fromJson(Map<String, dynamic> json) {
    return ChildProfile(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      familyId: json['family_id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? 'Child',
      age: json['age'] as int?,
      avatarIndex: json['avatar_index'] as int? ?? 0,
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
      'family_id': familyId,
      'nickname': nickname,
      'age': age,
      'avatar_index': avatarIndex,
      'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
    };
  }

  ChildProfile copyWith({
    String? nickname,
    int? age,
    int? avatarIndex,
    DateTime? updatedAt,
  }) {
    return ChildProfile(
      id: id,
      userId: userId,
      familyId: familyId,
      nickname: nickname ?? this.nickname,
      age: age ?? this.age,
      avatarIndex: avatarIndex ?? this.avatarIndex,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
