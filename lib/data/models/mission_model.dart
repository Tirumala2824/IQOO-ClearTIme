enum MissionStatus {
  available,
  started,
  inProgress,
  completed,
  expired,
}

enum MissionType {
  focus,
  breakMission,
  reading,
  custom,
}

class ChildMission {
  final String id;
  final String title;
  final String description;
  final String category;
  final MissionType type;
  final int targetMinutes;
  final int currentMinutes;
  final int points;
  final MissionStatus status;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const ChildMission({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.targetMinutes,
    this.currentMinutes = 0,
    required this.points,
    this.status = MissionStatus.available,
    this.startedAt,
    this.completedAt,
  });

  bool get isCompleted => status == MissionStatus.completed;

  double get progressRatio => targetMinutes > 0
      ? (currentMinutes / targetMinutes).clamp(0.0, 1.0)
      : (isCompleted ? 1.0 : 0.0);

  ChildMission copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    MissionType? type,
    int? targetMinutes,
    int? currentMinutes,
    int? points,
    MissionStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return ChildMission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      type: type ?? this.type,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      currentMinutes: currentMinutes ?? this.currentMinutes,
      points: points ?? this.points,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'type': type.name,
        'targetMinutes': targetMinutes,
        'currentMinutes': currentMinutes,
        'points': points,
        'status': status.name,
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ChildMission.fromJson(Map<String, dynamic> json) => ChildMission(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        type: MissionType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => MissionType.focus,
        ),
        targetMinutes: (json['targetMinutes'] as num).toInt(),
        currentMinutes: (json['currentMinutes'] as num? ?? 0).toInt(),
        points: (json['points'] as num).toInt(),
        status: MissionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => MissionStatus.available,
        ),
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );
}
