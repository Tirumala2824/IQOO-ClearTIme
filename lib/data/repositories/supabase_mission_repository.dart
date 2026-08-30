import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/mission_model.dart';
import 'local_mission_repository.dart';

/// Production repository for real cross-device activities.
///
/// The database RPCs own authorization and state transitions. Every operation
/// returns or queries the canonical database mission id, so parent creation,
/// child refresh, realtime subscriptions, and notification deep links all
/// reference the same id. The in-memory repository remains a test double
/// only; this class never manufactures data when the backend/session is
/// unavailable.
class SupabaseMissionRepository implements LocalMissionRepository {
  SupabaseMissionRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _safeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get _requireClient => _safeClient ??
      (throw StateError(
          'ClearTime is not connected. Please try again when the service is available.'));

  Map<String, dynamic> _fromDatabase(Map<String, dynamic> value) => {
        'id': value['id'],
        'title': value['title'],
        'description': value['description'] ?? '',
        'source': value['source'] ?? 'parent',
        'type': value['source'] == 'local_ai'
            ? MissionType.localAi.name
            : MissionType.parentAssigned.name,
        'targetMinutes': value['target_minutes'],
        'currentMinutes': value['current_minutes'],
        'status': value['status'],
        'dueDate': value['due_at'],
        'proofRequirement': value['proof_requirement'],
        'proofMediaPath': value['proof_media_path'],
        'proofMediaType': value['proof_media_type'],
        'submissionNotes': value['submission_notes'],
        'parentFeedback': value['parent_feedback'],
        'assignedByParentId': value['assigned_by_user_id'],
        'assignedToChildId': value['assigned_to_child_id'],
        'createdAt': value['created_at'],
        'startedAt': value['started_at'],
        'submittedAt': value['submitted_at'],
        'approvedAt': value['approved_at'],
        'completedAt': value['completed_at'],
      };

  ChildMission _mission(Map<String, dynamic> value) =>
      ChildMission.fromJson(_fromDatabase(value));

  @override
  Future<ChildMission> createParentTask(ChildMission task) async {
    final response = await _requireClient.rpc('create_parent_mission', params: {
      'p_mission': {
        'family_id': await _familyIdForChild(task.assignedToChildId),
        'assigned_to_child_id': task.assignedToChildId,
        'title': task.title.trim(),
        'description': task.description.trim(),
        'target_minutes': task.targetMinutes,
        'due_at': task.dueDate?.toIso8601String(),
        'proof_requirement': task.proofRequirement.name,
      },
    });
    if (response == null) {
      throw StateError('The activity was not saved.');
    }
    // The RPC returns the canonical database row; use it as the single
    // source of truth for the mission id.
    return _mission(Map<String, dynamic>.from(response as Map));
  }

  /// Auto-assigns an AI-created activity directly to the calling child.
  /// Enforced one-per-day until the previous one is finished/expired, and
  /// always source=local_ai with no proof requirement.
  @override
  Future<ChildMission> createLocalAiMission({
    required String title,
    String description = '',
    int targetMinutes = 30,
    DateTime? dueDate,
    String? childId,
    String? childNickname,
    String? familyId,
  }) async {
    final response = await _requireClient.rpc('create_local_ai_mission', params: {
      'p_title': title.trim(),
      'p_description': description.trim(),
      'p_target_minutes': targetMinutes,
      'p_due_at': dueDate?.toIso8601String(),
    });
    if (response == null) {
      throw StateError('The AI activity was not saved.');
    }
    return _mission(Map<String, dynamic>.from(response as Map));
  }

  @override
  Future<void> expireOverdueMissions() async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return;
    await client.rpc('expire_overdue_missions');
  }

  Future<String> _familyIdForChild(String? childId) async {
    if (childId == null || childId.isEmpty) {
      throw ArgumentError('An activity must be assigned to a real child.');
    }
    final record = await _requireClient
        .from('child_profiles')
        .select('family_id')
        .eq('id', childId)
        .maybeSingle();
    final familyId = record?['family_id'] as String?;
    if (familyId == null || familyId.isEmpty) {
      throw StateError('The selected child is no longer available.');
    }
    return familyId;
  }

  @override
  Future<List<ChildMission>> getMissions({String? childId}) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return const [];
    await expireOverdueMissions();

    String? targetChildId = childId;
    if (targetChildId == null || targetChildId.isEmpty) {
      // Look up child profile for currently authenticated user
      try {
        final profile = await client
            .from('child_profiles')
            .select('id')
            .eq('user_id', client.auth.currentUser!.id)
            .maybeSingle();
        targetChildId = profile?['id'] as String?;
      } catch (_) {}
    }

    // If targetChildId is still not found or could be a user_id, search by both
    final currentUserId = client.auth.currentUser!.id;
    try {
      if (targetChildId != null && targetChildId.isNotEmpty) {
        final rows = await client
            .from('missions')
            .select()
            .eq('assigned_to_child_id', targetChildId)
            .order('created_at', ascending: false);
        if ((rows as List).isNotEmpty) {
          return rows
              .map((row) => _mission(Map<String, dynamic>.from(row as Map)))
              .toList();
        }
      }

      // Fallback: look up by child profile linked to current user
      final profile = await client
          .from('child_profiles')
          .select('id')
          .eq('user_id', currentUserId)
          .maybeSingle();
      final resolvedId = profile?['id'] as String?;
      if (resolvedId != null && resolvedId.isNotEmpty) {
        final rows = await client
            .from('missions')
            .select()
            .eq('assigned_to_child_id', resolvedId)
            .order('created_at', ascending: false);
        return (rows as List)
            .map((row) => _mission(Map<String, dynamic>.from(row as Map)))
            .toList();
      }
    } catch (_) {}

    return const [];
  }

  @override
  Future<List<ChildMission>> getMissionsForParent({
    String? parentId,
    String? familyId,
  }) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return const [];
    final currentUid = client.auth.currentUser!.id;
    final effectiveParentId = (parentId != null && parentId.isNotEmpty) ? parentId : currentUid;

    var query = client.from('missions').select();
    if (familyId != null && familyId.isNotEmpty) {
      query = query.eq('family_id', familyId);
    } else if (effectiveParentId.isNotEmpty) {
      query = query.eq('assigned_by_user_id', effectiveParentId);
    }

    try {
      final rows = await query.order('created_at', ascending: false);
      return (rows as List)
          .map((row) => _mission(Map<String, dynamic>.from(row as Map)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ChildMission?> getMissionById(String id) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return null;
    final row =
        await client.from('missions').select().eq('id', id).maybeSingle();
    return row == null ? null : _mission(Map<String, dynamic>.from(row));
  }

  @override
  Future<void> startMission(String id, {String? childId}) async {
    await _requireClient.rpc('start_child_mission', params: {'p_mission_id': id});
  }

  @override
  Future<void> submitMission(String id,
      {String? mediaPath,
      String? mediaType,
      String? notes,
      String? childId}) async {
    await _requireClient.rpc('submit_child_mission', params: {
      'p_mission_id': id,
      'p_media_path': mediaPath,
      'p_media_type': mediaType,
      'p_notes': notes,
    });
  }

  @override
  Future<void> approveMission(String id, {String? parentFeedback}) async {
    await _requireClient.rpc('review_mission', params: {
      'p_mission_id': id,
      'p_approved': true,
      'p_feedback': parentFeedback,
    });
  }

  @override
  Future<void> rejectMissionNeedsRetry(String id, {String? feedback}) async {
    await _requireClient.rpc('review_mission', params: {
      'p_mission_id': id,
      'p_approved': false,
      'p_feedback': feedback,
    });
  }

  @override
  Future<void> saveMission(ChildMission mission) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return;
    try {
      await client.from('missions').update({
        'title': mission.title.trim(),
        'description': mission.description.trim(),
        'target_minutes': mission.targetMinutes,
        'due_at': mission.dueDate?.toIso8601String(),
        'proof_requirement': mission.proofRequirement.name,
        'status': mission.status.name,
        'parent_feedback': mission.parentFeedback,
      }).eq('id', mission.id);
    } catch (_) {}
  }

  @override
  Future<void> deleteMission(String id) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return;
    // 1. Delete associated rewards
    try {
      await client.from('rewards').delete().eq('task_id', id);
    } catch (_) {}
    // 2. Delete mission
    try {
      await client.from('missions').delete().eq('id', id);
    } catch (e) {
      try {
        await client.from('missions').update({'status': 'expired'}).eq('id', id);
      } catch (_) {}
    }
  }

  @override
  Future<void> updateMissionProgress(String id, int minutes) async {}
  @override
  Future<void> completeMission(String id) async {
    await approveMission(id);
  }
  @override
  Future<void> resetDailyMissions() async {}
  @override
  Future<void> checkAndExpireMissions() => expireOverdueMissions();
  @override
  Future<List<ChildMission>> generateDynamicMissions(
          {required dynamic usage, required List<dynamic> patterns}) async =>
      const [];
}