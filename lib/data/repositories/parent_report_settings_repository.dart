import '../models/approved_report_model.dart';

abstract class ParentReportSettingsRepository {
  Future<ParentReportSettings> getSettings(String familyId);
  Future<void> updateSettings(String familyId, ParentReportSettings settings);
}

/// In-memory repository for parent report configuration settings.
class InMemoryParentReportSettingsRepository
    implements ParentReportSettingsRepository {
  final Map<String, ParentReportSettings> _storage = {};

  InMemoryParentReportSettingsRepository({ParentReportSettings? initialSettings}) {
    if (initialSettings != null) {
      _storage['default'] = initialSettings;
    }
  }

  @override
  Future<ParentReportSettings> getSettings(String familyId) async {
    return _storage[familyId] ??
        _storage['default'] ??
        const ParentReportSettings();
  }

  @override
  Future<void> updateSettings(
      String familyId, ParentReportSettings settings) async {
    _storage[familyId] = settings;
    _storage['default'] = settings;
  }
}
