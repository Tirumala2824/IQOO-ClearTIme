enum MissionStatus {
  assigned,
  started,
  submitted,
  approved,
  needsRetry,
  expired;

  /// Plain activity status language. No gamified terms.
  String get label {
    switch (this) {
      case MissionStatus.assigned:
        return 'To do';
      case MissionStatus.started:
        return 'In progress';
      case MissionStatus.submitted:
        return 'Sent for review';
      case MissionStatus.approved:
        return 'Finished';
      case MissionStatus.needsRetry:
        return 'Try again';
      case MissionStatus.expired:
        return 'Expired';
    }
  }

  static MissionStatus fromString(String? name) {
    if (name == null) return MissionStatus.assigned;
    if (name == 'available') return MissionStatus.assigned;
    if (name == 'inProgress') return MissionStatus.started;
    if (name == 'completed') return MissionStatus.approved;
    if (name == 'needsRetry') return MissionStatus.needsRetry;
    if (name == 'needs_retry') return MissionStatus.needsRetry;
    return MissionStatus.values
            .where((s) => s.name == name)
            .firstOrNull ??
        MissionStatus.assigned;
  }
}

enum ProofRequirement {
  noProof,
  photo,
  video,
  parentApproval,
  photoVideoParentApproval;

  String get label {
    switch (this) {
      case ProofRequirement.noProof:
        return 'No proof';
      case ProofRequirement.photo:
        return 'Photo';
      case ProofRequirement.video:
        return 'Short video';
      case ProofRequirement.parentApproval:
        return 'Parent approval';
      case ProofRequirement.photoVideoParentApproval:
        return 'Photo/video + parent approval';
    }
  }

  static ProofRequirement fromString(String? name) {
    if (name == null) return ProofRequirement.noProof;
    if (name == 'no_proof') return ProofRequirement.noProof;
    if (name == 'parent_approval') return ProofRequirement.parentApproval;
    if (name == 'photo_video_parent_approval') {
      return ProofRequirement.photoVideoParentApproval;
    }
    return ProofRequirement.values
            .where((p) => p.name == name)
            .firstOrNull ??
        ProofRequirement.noProof;
  }
}

/// Where an activity came from: a linked parent or the child device's local AI.
enum MissionSource {
  parent,
  localAi,
}

enum MissionType {
  parentAssigned,
  localAi,
  focus,
  breakMission,
  reading,
  custom,
}

class ChildMission {
  final String id;
  final String title;
  final String description;
  final MissionSource source;
  final MissionType type;
  final int targetMinutes;
  final int currentMinutes;
  final MissionStatus status;
  final String? reward;
  final DateTime? dueDate;
  final ProofRequirement proofRequirement;
  final String? proofMediaPath;
  final String? proofMediaType;
  final String? submissionNotes;
  final String? parentFeedback;
  final String? assignedByParentId;
  final String? assignedToChildId;
  final String? assignedToChildNickname;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final DateTime? completedAt;

  ChildMission({
    required this.id,
    required this.title,
    required this.description,
    this.source = MissionSource.parent,
    this.type = MissionType.parentAssigned,
    required this.targetMinutes,
    this.currentMinutes = 0,
    this.status = MissionStatus.assigned,
    this.reward,
    this.dueDate,
    this.proofRequirement = ProofRequirement.noProof,
    this.proofMediaPath,
    this.proofMediaType,
    this.submissionNotes,
    this.parentFeedback,
    this.assignedByParentId,
    this.assignedToChildId,
    this.assignedToChildNickname,
    DateTime? createdAt,
    this.startedAt,
    this.submittedAt,
    this.approvedAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isCompleted => status == MissionStatus.approved;
  bool get isPendingApproval => status == MissionStatus.submitted;
  bool get isNeedsRetry => status == MissionStatus.needsRetry;
  bool get isStarted => status == MissionStatus.started;
  bool get isAssigned => status == MissionStatus.assigned;
  
  bool get isExpired {
    if (status == MissionStatus.expired) return true;
    if (dueDate != null && DateTime.now().isAfter(dueDate!) && !isCompleted) {
      return true;
    }
    return false;
  }

  bool get requiresMediaProof =>
      proofRequirement == ProofRequirement.photo ||
      proofRequirement == ProofRequirement.video ||
      proofRequirement == ProofRequirement.photoVideoParentApproval;

  bool get requiresParentApproval =>
      proofRequirement == ProofRequirement.parentApproval ||
      proofRequirement == ProofRequirement.photoVideoParentApproval;

  double get progressRatio => targetMinutes > 0
      ? (currentMinutes / targetMinutes).clamp(0.0, 1.0)
      : (isCompleted ? 1.0 : 0.0);

  ChildMission copyWith({
    String? id,
    String? title,
    String? description,
    MissionSource? source,
    MissionType? type,
    int? targetMinutes,
    int? currentMinutes,
    MissionStatus? status,
    String? reward,
    DateTime? dueDate,
    ProofRequirement? proofRequirement,
    String? proofMediaPath,
    String? proofMediaType,
    String? submissionNotes,
    String? parentFeedback,
    String? assignedByParentId,
    String? assignedToChildId,
    String? assignedToChildNickname,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? submittedAt,
    DateTime? approvedAt,
    DateTime? completedAt,
  }) {
    return ChildMission(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      source: source ?? this.source,
      type: type ?? this.type,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      currentMinutes: currentMinutes ?? this.currentMinutes,
      status: status ?? this.status,
      reward: reward ?? this.reward,
      dueDate: dueDate ?? this.dueDate,
      proofRequirement: proofRequirement ?? this.proofRequirement,
      proofMediaPath: proofMediaPath ?? this.proofMediaPath,
      proofMediaType: proofMediaType ?? this.proofMediaType,
      submissionNotes: submissionNotes ?? this.submissionNotes,
      parentFeedback: parentFeedback ?? this.parentFeedback,
      assignedByParentId: assignedByParentId ?? this.assignedByParentId,
      assignedToChildId: assignedToChildId ?? this.assignedToChildId,
      assignedToChildNickname:
          assignedToChildNickname ?? this.assignedToChildNickname,
      createdAt: createdAt ?? this.createdAt,
      startedAt: startedAt ?? this.startedAt,
      submittedAt: submittedAt ?? this.submittedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'source': source.name,
        'type': type.name,
        'targetMinutes': targetMinutes,
        'currentMinutes': currentMinutes,
        'status': status.name,
        'reward': reward,
        'dueDate': dueDate?.toIso8601String(),
        'proofRequirement': proofRequirement.name,
        'proofMediaPath': proofMediaPath,
        'proofMediaType': proofMediaType,
        'submissionNotes': submissionNotes,
        'parentFeedback': parentFeedback,
        'assignedByParentId': assignedByParentId,
        'assignedToChildId': assignedToChildId,
        'assignedToChildNickname': assignedToChildNickname,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'submittedAt': submittedAt?.toIso8601String(),
        'approvedAt': approvedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ChildMission.fromJson(Map<String, dynamic> json) => ChildMission(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String? ?? '',
        source: json['source'] != null
            ? (MissionSource.values
                    .where((s) => s.name == json['source'])
                    .firstOrNull ??
                MissionSource.parent)
            : (json['type'] == MissionType.localAi.name
                ? MissionSource.localAi
                : MissionSource.parent),
        type: MissionType.values
                .where((t) => t.name == json['type'])
                .firstOrNull ??
            MissionType.parentAssigned,
        targetMinutes: (json['targetMinutes'] as num? ?? 1).toInt(),
        currentMinutes: (json['currentMinutes'] as num? ?? 0).toInt(),
        status: MissionStatus.fromString(json['status'] as String?),
        reward: json['reward'] as String?,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        proofRequirement:
            ProofRequirement.fromString(json['proofRequirement'] as String?),
        proofMediaPath: json['proofMediaPath'] as String?,
        proofMediaType: json['proofMediaType'] as String?,
        submissionNotes: json['submissionNotes'] as String?,
        parentFeedback: json['parentFeedback'] as String?,
        assignedByParentId: json['assignedByParentId'] as String?,
        assignedToChildId: json['assignedToChildId'] as String?,
        assignedToChildNickname: json['assignedToChildNickname'] as String?,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        startedAt: json['startedAt'] != null
            ? DateTime.parse(json['startedAt'] as String)
            : null,
        submittedAt: json['submittedAt'] != null
            ? DateTime.parse(json['submittedAt'] as String)
            : null,
        approvedAt: json['approvedAt'] != null
            ? DateTime.parse(json['approvedAt'] as String)
            : null,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
      );
}
