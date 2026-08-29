enum GoalType {
  dailyFocus,
  weeklyFocus,
  breakGoal,
  digitalBalance,
}

enum GoalStatus {
  active,
  paused,
  completed,
}

class ChildGoal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final int targetMinutes; // or target count for breakGoal
  final int currentMinutes; // or current count for breakGoal
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ChildGoal({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetMinutes,
    this.currentMinutes = 0,
    this.status = GoalStatus.active,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isCompleted => currentMinutes >= targetMinutes;

  double get progressRatio => targetMinutes > 0
      ? (currentMinutes / targetMinutes).clamp(0.0, 1.0)
      : 0.0;

  int get progressPercentage => (progressRatio * 100).round();

  ChildGoal copyWith({
    String? id,
    String? title,
    String? description,
    GoalType? type,
    int? targetMinutes,
    int? currentMinutes,
    GoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ChildGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      currentMinutes: currentMinutes ?? this.currentMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'targetMinutes': targetMinutes,
        'currentMinutes': currentMinutes,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ChildGoal.fromJson(Map<String, dynamic> json) => ChildGoal(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        type: GoalType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => GoalType.dailyFocus,
        ),
        targetMinutes: (json['targetMinutes'] as num).toInt(),
        currentMinutes: (json['currentMinutes'] as num? ?? 0).toInt(),
        status: GoalStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => GoalStatus.active,
        ),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}
