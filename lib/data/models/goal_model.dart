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
  expired,
}

enum GoalSource {
  aiGenerated,
  userCreated,
  parentAssigned,
}

class ChildGoal {
  final String id;
  final String title;
  final String description;
  final GoalType type;
  final int targetMinutes; // or target count for breakGoal
  final int currentMinutes; // or current count for breakGoal
  final GoalStatus status;
  final GoalSource source;
  final String? evaluationResult; // e.g. "improved", "struggled"
  final String? relatedPattern; // description of pattern that triggered this goal
  final DateTime? expiresAt; // when this goal is no longer valid
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
    this.source = GoalSource.userCreated,
    this.evaluationResult,
    this.relatedPattern,
    this.expiresAt,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isCompleted => currentMinutes >= targetMinutes;
  bool get isAIGenerated => source == GoalSource.aiGenerated;
  bool get isExpired {
    if (status == GoalStatus.expired) return true;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return true;
    return false;
  }

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
    GoalSource? source,
    String? evaluationResult,
    String? relatedPattern,
    DateTime? expiresAt,
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
      source: source ?? this.source,
      evaluationResult: evaluationResult ?? this.evaluationResult,
      relatedPattern: relatedPattern ?? this.relatedPattern,
      expiresAt: expiresAt ?? this.expiresAt,
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
        'source': source.name,
        'evaluationResult': evaluationResult,
        'relatedPattern': relatedPattern,
        'expiresAt': expiresAt?.toIso8601String(),
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
        source: GoalSource.values.firstWhere(
          (s) => s.name == (json['source'] as String?),
          orElse: () => GoalSource.userCreated,
        ),
        evaluationResult: json['evaluationResult'] as String?,
        relatedPattern: json['relatedPattern'] as String?,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : null,
      );
}
