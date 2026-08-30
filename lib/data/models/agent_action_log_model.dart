import 'package:uuid/uuid.dart';

enum AgentActionType {
  activityDispatch,
  habitIntervention,
  reportSynthesis,
  downtimeEnforcement,
  goalRecommendation,
  routineOptimization,
  systemHeartbeat,
}

enum AgentActionStatus {
  success,
  pending,
  failed,
  scheduled,
}

/// Structured record of an action autonomously executed or recommended
/// by the ClearTime AI Agent.
class AgentActionLog {
  final String id;
  final String title;
  final String description;
  final AgentActionType actionType;
  final AgentActionStatus status;
  final DateTime timestamp;
  final String? targetChildName;
  final String? targetChildId;
  final Map<String, dynamic>? metadata;

  const AgentActionLog({
    required this.id,
    required this.title,
    required this.description,
    required this.actionType,
    required this.status,
    required this.timestamp,
    this.targetChildName,
    this.targetChildId,
    this.metadata,
  });

  factory AgentActionLog.create({
    required String title,
    required String description,
    required AgentActionType actionType,
    AgentActionStatus status = AgentActionStatus.success,
    String? targetChildName,
    String? targetChildId,
    Map<String, dynamic>? metadata,
  }) {
    return AgentActionLog(
      id: const Uuid().v4(),
      title: title,
      description: description,
      actionType: actionType,
      status: status,
      timestamp: DateTime.now(),
      targetChildName: targetChildName,
      targetChildId: targetChildId,
      metadata: metadata,
    );
  }

  factory AgentActionLog.fromJson(Map<String, dynamic> json) {
    return AgentActionLog(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? 'Automated Action',
      description: json['description'] as String? ?? '',
      actionType: AgentActionType.values
              .where((e) => e.name == json['actionType'])
              .firstOrNull ??
          AgentActionType.systemHeartbeat,
      status: AgentActionStatus.values
              .where((e) => e.name == json['status'])
              .firstOrNull ??
          AgentActionStatus.success,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      targetChildName: json['targetChildName'] as String?,
      targetChildId: json['targetChildId'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'actionType': actionType.name,
      'status': status.name,
      'timestamp': timestamp.toIso8601String(),
      if (targetChildName != null) 'targetChildName': targetChildName,
      if (targetChildId != null) 'targetChildId': targetChildId,
      if (metadata != null) 'metadata': metadata,
    };
  }

  AgentActionLog copyWith({
    String? id,
    String? title,
    String? description,
    AgentActionType? actionType,
    AgentActionStatus? status,
    DateTime? timestamp,
    String? targetChildName,
    String? targetChildId,
    Map<String, dynamic>? metadata,
  }) {
    return AgentActionLog(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      actionType: actionType ?? this.actionType,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      targetChildName: targetChildName ?? this.targetChildName,
      targetChildId: targetChildId ?? this.targetChildId,
      metadata: metadata ?? this.metadata,
    );
  }
}
