/// Lifecycle status of a real-world family reward.
///
/// Status transitions are driven exclusively by real business events:
/// [locked] -> [unlocked] when the associated task satisfies its configured
/// unlock condition (e.g. parent approval).
/// [unlocked] -> [redeemed] only through an explicit redemption action.
/// Any state -> [cancelled] only through an authorized cancellation operation.
enum RewardStatus {
  locked,
  unlocked,
  redeemed,
  cancelled;

  String get label {
    switch (this) {
      case RewardStatus.locked:
        return 'Locked';
      case RewardStatus.unlocked:
        return 'Unlocked';
      case RewardStatus.redeemed:
        return 'Redeemed';
      case RewardStatus.cancelled:
        return 'Cancelled';
    }
  }

  static RewardStatus fromString(String? name) {
    return RewardStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => RewardStatus.locked,
    );
  }
}

/// A positive real-world family reward attached to a parent-assigned task.
///
/// The reward stays [locked] until the actual unlock condition is satisfied;
/// it is never unlocked merely because a task was assigned or started.
class Reward {
  final String id;
  final String parentId;
  final String childId;
  final String taskId;
  final String title;
  final String? description;
  final RewardStatus status;
  final DateTime? createdAt;
  final DateTime? unlockedAt;
  final DateTime? redeemedAt;
  final DateTime? cancelledAt;

  const Reward({
    required this.id,
    required this.parentId,
    required this.childId,
    required this.taskId,
    required this.title,
    this.description,
    this.status = RewardStatus.locked,
    this.createdAt,
    this.unlockedAt,
    this.redeemedAt,
    this.cancelledAt,
  });

  /// Non-const derived creation date defaults to epoch rather than a fake
  /// "now": only a real persisted reward carries a real creation time.
  DateTime get createdDate => createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  bool get isLocked => status == RewardStatus.locked;
  bool get isUnlocked => status == RewardStatus.unlocked;
  bool get isRedeemed => status == RewardStatus.redeemed;
  bool get isCancelled => status == RewardStatus.cancelled;

  Reward copyWith({
    String? title,
    String? description,
    RewardStatus? status,
    DateTime? unlockedAt,
    DateTime? redeemedAt,
    DateTime? cancelledAt,
  }) {
    return Reward(
      id: id,
      parentId: parentId,
      childId: childId,
      taskId: taskId,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      createdAt: createdAt,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      redeemedAt: redeemedAt ?? this.redeemedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'parentId': parentId,
        'childId': childId,
        'taskId': taskId,
        'title': title,
        'description': description,
        'status': status.name,
        'createdAt': createdAt?.toIso8601String(),
        'unlockedAt': unlockedAt?.toIso8601String(),
        'redeemedAt': redeemedAt?.toIso8601String(),
        'cancelledAt': cancelledAt?.toIso8601String(),
      };

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] as String,
      parentId: json['parentId'] as String? ?? '',
      childId: json['childId'] as String? ?? '',
      taskId: json['taskId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      status: RewardStatus.fromString(json['status'] as String?),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.parse(json['unlockedAt'] as String)
          : null,
      redeemedAt: json['redeemedAt'] != null
          ? DateTime.parse(json['redeemedAt'] as String)
          : null,
      cancelledAt: json['cancelledAt'] != null
          ? DateTime.parse(json['cancelledAt'] as String)
          : null,
    );
  }
}
