import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/approved_report_model.dart';

/// Result of an attempt to generate an approved report for a request.
class ReportGenerationOutcome {
  final bool generated;
  final String status; // ready | unavailable
  final ApprovedReport? report;
  final String reason;

  const ReportGenerationOutcome.generated(this.report)
      : generated = true,
        status = 'ready',
        reason = '';

  const ReportGenerationOutcome.unavailable(this.reason)
      : generated = false,
        status = 'unavailable',
        report = null;
}

/// Parent requests and child completions for the durable report queue.
///
/// Every request stays queued until the child device comes online and
/// generates the filtered snapshot; nothing claims a report was delivered
/// before that generation completes server-side.
class ReportRequestService {
  ReportRequestService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _safeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Linked parent requests a report for a child. Idempotent on the server.
  Future<Map<String, dynamic>?> requestReport({
    required String childId,
    String period = 'daily',
  }) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return null;
    final row = await client.rpc('request_approved_report', params: {
      'p_child_id': childId,
      'p_period': period,
    });
    if (row == null) return null;
    return Map<String, dynamic>.from(row as Map);
  }

  /// Requests the child device can currently work on.
  Future<List<Map<String, dynamic>>> pendingRequestsForChild() async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client
        .from('report_requests')
        .select()
        .inFilter('status', ['preparing', 'waiting_for_child'])
        .order('requested_at', ascending: true);
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  Future<void> acknowledge(String requestId) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return;
    await client.rpc('ack_report_request', params: {'p_request_id': requestId});
  }

  Future<void> complete({
    required String requestId,
    required String status,
    String? reportId,
    String? failureReason,
  }) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return;
    await client.rpc('complete_report_request', params: {
      'p_request_id': requestId,
      'p_status': status,
      'p_report_id': reportId,
      'p_failure_reason': failureReason,
    });
  }

  /// Requests for a linked parent to display with truthful states.
  Future<List<Map<String, dynamic>>> requestsForParent() async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return const [];
    final rows = await client
        .from('report_requests')
        .select()
        .order('requested_at', ascending: false);
    return (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }
}

/// Human-facing truth of a report request status.
String reportRequestStatusLabel(String status) {
  switch (status) {
    case 'preparing':
      return 'Preparing';
    case 'waiting_for_child':
      return 'Waiting for child device';
    case 'ready':
      return 'Ready';
    case 'unavailable':
      return 'Unavailable';
    case 'failed':
      return 'Failed';
    default:
      return status;
  }
}