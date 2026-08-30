import '../models/approved_report_model.dart';
import '../../core/privacy/privacy_guard.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class ApprovedReportRepository {
  Future<List<ApprovedReport>> getApprovedReports(String childId);
  Future<ApprovedReport?> getApprovedReport(String reportId);
  Future<List<ApprovedReport>> getReportHistory(String childId,
      {ReportPeriod? period});
  Future<void> saveApprovedReport(ApprovedReport report);
  Future<List<ApprovedReport>> getMultiChildApprovedReports(
      List<String> childIds);
  Future<void> deleteApprovedReport(String reportId);
  Future<void> clearLocalCache();
}

/// Encrypted on-device persistence for approved report snapshots.
///
/// Reports are built only from locally stored aggregates. There is no sample
/// or fallback data: a device with no collected aggregates has no reports.
class EncryptedApprovedReportRepository implements ApprovedReportRepository {
  final EncryptedDeviceStore _store;

  EncryptedApprovedReportRepository({required EncryptedDeviceStore store})
      : _store = store;

  @override
  Future<List<ApprovedReport>> getApprovedReports(String childId) async {
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.approvedReportsBox,
      onCorrupt: (key, _) =>
          _store.delete(EncryptedDeviceStore.approvedReportsBox, key),
    );
    final reports = <ApprovedReport>[];
    for (final json in jsons) {
      try {
        final report = ApprovedReport.fromJson(json);
        if (report.childId == childId) reports.add(report);
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  @override
  Future<ApprovedReport?> getApprovedReport(String reportId) async {
    final json = await _store.getJson(
      EncryptedDeviceStore.approvedReportsBox,
      reportId,
    );
    if (json == null) return null;
    try {
      return ApprovedReport.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<ApprovedReport>> getReportHistory(String childId,
      {ReportPeriod? period}) async {
    final reports = await getApprovedReports(childId);
    final filtered = reports
        .where((r) => period == null || r.period == period)
        .toList();
    filtered.sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return filtered;
  }

  @override
  Future<void> saveApprovedReport(ApprovedReport report) async {
    // Architectural security assertion: nothing raw may cross into storage.
    PrivacyGuard.assertCloudSafe(report.toJson());
    await _store.putJson(
      EncryptedDeviceStore.approvedReportsBox,
      report.id,
      report.toJson(),
    );
  }

  @override
  Future<List<ApprovedReport>> getMultiChildApprovedReports(
      List<String> childIds) async {
    final idSet = childIds.toSet();
    final jsons = await _store.getAllJson(
      EncryptedDeviceStore.approvedReportsBox,
    );
    final reports = <ApprovedReport>[];
    for (final json in jsons) {
      try {
        final report = ApprovedReport.fromJson(json);
        if (idSet.contains(report.childId)) reports.add(report);
      } catch (_) {
        // Skip corrupted entries.
      }
    }
    reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return reports;
  }

  @override
  Future<void> deleteApprovedReport(String reportId) async {
    await _store.delete(EncryptedDeviceStore.approvedReportsBox, reportId);
  }

  @override
  Future<void> clearLocalCache() async {
    await _store.clearBox(EncryptedDeviceStore.approvedReportsBox);
  }
}