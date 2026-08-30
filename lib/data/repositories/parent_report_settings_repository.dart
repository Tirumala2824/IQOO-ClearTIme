import '../models/approved_report_model.dart';
import '../../services/storage/encrypted_device_store.dart';

abstract class ParentReportSettingsRepository {
  Future<ParentReportSettings> getSettings(String familyId);
  Future<void> updateSettings(String familyId, ParentReportSettings settings);
}

/// Encrypted on-device persistence for parent report settings.
class EncryptedParentReportSettingsRepository
    implements ParentReportSettingsRepository {
  final EncryptedDeviceStore _store;

  EncryptedParentReportSettingsRepository({required EncryptedDeviceStore store})
      : _store = store;

  @override
  Future<ParentReportSettings> getSettings(String familyId) async {
    final json = await _store.getJson(
      EncryptedDeviceStore.reportSettingsBox,
      familyId,
    );
    if (json == null) return const ParentReportSettings();
    try {
      return ParentReportSettings.fromJson(json);
    } catch (_) {
      return const ParentReportSettings();
    }
  }

  @override
  Future<void> updateSettings(
      String familyId, ParentReportSettings settings) async {
    await _store.putJson(
      EncryptedDeviceStore.reportSettingsBox,
      familyId,
      settings.toJson(),
    );
  }
}