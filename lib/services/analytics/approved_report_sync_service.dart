import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/privacy/privacy_guard.dart';
import '../../data/models/approved_report_model.dart';
import '../../data/repositories/approved_report_repository.dart';

/// Syncs privacy-filtered approved report snapshots.
///
/// The child device uploads a filtered snapshot to the `approved_reports`
/// table (RLS: only the child can insert, linked parents can select).
/// The parent device downloads the same snapshots into its local encrypted
/// cache. Nothing else is ever shared.
class ApprovedReportSyncService {
  final SupabaseClient? _client;
  final ApprovedReportRepository _localRepo;

  ApprovedReportSyncService({
    SupabaseClient? client,
    required ApprovedReportRepository localRepo,
  })  : _client = client,
        _localRepo = localRepo;

  SupabaseClient? get _safeClient {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Uploads a filtered snapshot. Returns false when offline/unauthorized —
  /// the durable report request queue remains the fallback.
  Future<bool> pushSnapshot(ApprovedReport report) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return false;

    try {
      PrivacyGuard.assertCloudSafe(report.toJson());
      final payload = report.toJson();
      payload['understand_act'] = report.understandActSections;
      await client.from('approved_reports').upsert({
        'id': report.id,
        'family_id': report.familyId,
        'child_id': report.childId,
        'created_by_user_id': client.auth.currentUser!.id,
        'period': report.period.toDbString().toLowerCase(),
        'period_start': report.periodStart.toIso8601String(),
        'period_end': report.periodEnd.toIso8601String(),
        'detail_level': report.detailLevel.toDbString().toLowerCase(),
        'facts': payload['facts'],
        'understand_act': payload['understand_act'] ?? const {},
        'categories': report.categories.map((c) => c.name).toList(),
        'versions': {
          'context': report.contextVersion,
          'privacy': report.privacyFilterVersion,
          'analytics': report.analyticsVersion,
          'config': report.configVersion,
        },
        'is_snapshot': true,
      }, onConflict: 'child_id, period, period_start');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads snapshots for a linked child into the local encrypted cache.
  Future<List<ApprovedReport>> pullSnapshots(String childId) async {
    final client = _safeClient;
    if (client == null || client.auth.currentUser == null) return const [];

    try {
      final rows = await client
          .from('approved_reports')
          .select()
          .eq('child_id', childId)
          .order('created_at', ascending: false);
      final reports = <ApprovedReport>[];
      for (final row in (rows as List)) {
        final map = Map<String, dynamic>.from(row as Map);
        final report = ApprovedReport.fromJson({
          'id': map['id'],
          'childId': childId,
          'familyId': map['family_id'],
          'period': map['period'],
          'periodStart': map['period_start'],
          'periodEnd': map['period_end'],
          'detailLevel': map['detail_level'],
          'facts': map['facts'],
          'categories': map['categories'],
          'understand_act': map['understand_act'],
          'creation': map['created_at'],
        });
        await _localRepo.saveApprovedReport(report);
        reports.add(report);
      }
      return reports;
    } catch (_) {
      return const [];
    }
  }
}