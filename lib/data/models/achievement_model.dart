enum AchievementType {
  focusStarter,
  breakMaster,
  sevenDayBalance,
  consistencyChampion,
  deepFocus,
}

class ChildAchievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final AchievementType type;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final double progress; // 0.0 to 1.0
  final int requirementValue;
  final int currentValue;
  final String requirementLabel;

  const ChildAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.type,
    this.isUnlocked = false,
    this.unlockedAt,
    this.progress = 0.0,
    required this.requirementValue,
    this.currentValue = 0,
    required this.requirementLabel,
  });

  ChildAchievement copyWith({
    String? id,
    String? title,
    String? description,
    String? icon,
    AchievementType? type,
    bool? isUnlocked,
    DateTime? unlockedAt,
    double? progress,
    int? requirementValue,
    int? currentValue,
    String? requirementLabel,
  }) {
    return ChildAchievement(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      type: type ?? this.type,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      progress: progress ?? this.progress,
      requirementValue: requirementValue ?? this.requirementValue,
      currentValue: currentValue ?? this.currentValue,
      requirementLabel: requirementLabel ?? this.requirementLabel,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'icon': icon,
        'type': type.name,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'progress': progress,
        'requirementValue': requirementValue,
        'currentValue': currentValue,
        'requirementLabel': requirementLabel,
      };

  factory ChildAchievement.fromJson(Map<String, dynamic> json) =>
      ChildAchievement(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        icon: json['icon'] as String,
        type: AchievementType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AchievementType.focusStarter,
        ),
        isUnlocked: json['isUnlocked'] as bool? ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.parse(json['unlockedAt'] as String)
            : null,
        progress: (json['progress'] as num? ?? 0.0).toDouble(),
        requirementValue: (json['requirementValue'] as num).toInt(),
        currentValue: (json['currentValue'] as num? ?? 0).toInt(),
        requirementLabel: json['requirementLabel'] as String,
      );
}
