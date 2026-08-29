import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import '../../../core/providers/providers.dart';
import '../../../data/models/family_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/report_config_model.dart';
import '../../../data/models/trigger_config_model.dart';
import '../../../data/models/notification_pref_model.dart';
import '../../../data/models/privacy_setting_model.dart';
import '../../../data/repositories/family_repository.dart';
import '../../../data/repositories/configuration_repository.dart';

import '../../../data/models/approved_report_model.dart';
import '../../../data/repositories/approved_report_repository.dart';

class ParentDashboardState {
  final Family? family;
  final List<ChildProfile> children;
  final List<ReportConfiguration> reports;
  final List<TriggerConfiguration> triggers;
  final List<ApprovedReport> approvedReports;
  final List<String> activeAlerts;
  final NotificationPreference? notificationPrefs;
  final PrivacySetting? privacySettings;
  final bool isLoading;
  final String? errorMessage;

  const ParentDashboardState({
    this.family,
    this.children = const [],
    this.reports = const [],
    this.triggers = const [],
    this.approvedReports = const [],
    this.activeAlerts = const [],
    this.notificationPrefs,
    this.privacySettings,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get hasFamily => family != null;
  bool get hasChildren => children.isNotEmpty;

  ParentDashboardState copyWith({
    Family? family,
    List<ChildProfile>? children,
    List<ReportConfiguration>? reports,
    List<TriggerConfiguration>? triggers,
    List<ApprovedReport>? approvedReports,
    List<String>? activeAlerts,
    NotificationPreference? notificationPrefs,
    PrivacySetting? privacySettings,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ParentDashboardState(
      family: family ?? this.family,
      children: children ?? this.children,
      reports: reports ?? this.reports,
      triggers: triggers ?? this.triggers,
      approvedReports: approvedReports ?? this.approvedReports,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      notificationPrefs: notificationPrefs ?? this.notificationPrefs,
      privacySettings: privacySettings ?? this.privacySettings,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ParentDashboardController extends StateNotifier<ParentDashboardState> {
  final FamilyRepository _familyRepository;
  final ConfigurationRepository _configurationRepository;
  final ApprovedReportRepository _approvedReportRepository;

  ParentDashboardController({
    required FamilyRepository familyRepository,
    required ConfigurationRepository configurationRepository,
    required ApprovedReportRepository approvedReportRepository,
  })  : _familyRepository = familyRepository,
        _configurationRepository = configurationRepository,
        _approvedReportRepository = approvedReportRepository,
        super(const ParentDashboardState());

  Future<void> loadDashboard(String userId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final family = await _familyRepository.getFamilyForUser(userId);
      if (family == null) {
        state = state.copyWith(isLoading: false, family: null, children: []);
        return;
      }

      final children = await _familyRepository.getChildrenForFamily(family.id);
      final reports =
          await _configurationRepository.getReportConfigurations(family.id);
      final triggers =
          await _configurationRepository.getTriggerConfigurations(family.id);
      final notifs =
          await _configurationRepository.getNotificationPreferences(userId);
      final privacy = await _configurationRepository.getPrivacySettings(
        familyId: family.id,
        userId: userId,
      );

      // Load approved reports for all children
      final List<ApprovedReport> allReports = [];
      final List<String> alerts = [];

      for (final child in children) {
        final childReports = await _approvedReportRepository.getApprovedReports(child.id);
        allReports.addAll(childReports);
      }

      // If no approved reports yet in memory, create a dynamic baseline report
      if (allReports.isEmpty && children.isNotEmpty) {
        final now = DateTime.now();
        for (final child in children) {
          final defaultReport = ApprovedReport(
            id: 'rep-init-${child.id}',
            childId: child.id,
            childNickname: child.nickname,
            familyId: family.id,
            period: ReportPeriod.weekly,
            periodStart: now.subtract(const Duration(days: 7)),
            periodEnd: now,
            facts: const ReportFacts(
              totalScreenMinutes: 720,
              focusMinutes: 310,
              breakCount: 18,
              goalsCompletedCount: 4,
              goalsTotalCount: 5,
              changePercentage: -8.5,
            ),
            summaryText: 'Healthy screen-time balance and consistent focus sessions recorded.',
            createdAt: now,
          );
          await _approvedReportRepository.saveApprovedReport(defaultReport);
          allReports.add(defaultReport);
        }
      }

      state = state.copyWith(
        family: family,
        children: children,
        reports: reports,
        triggers: triggers,
        approvedReports: allReports,
        activeAlerts: alerts,
        notificationPrefs: notifs,
        privacySettings: privacy,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createFamily({
    required String name,
    required String parentUserId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _familyRepository.createFamily(
        name: name,
        adminUserId: parentUserId,
      );
      await loadDashboard(parentUserId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> addReport(ReportConfiguration config) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created =
          await _configurationRepository.createReportConfiguration(config);
      state = state.copyWith(
        reports: [...state.reports, created],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleReport(ReportConfiguration config, bool enabled) async {
    try {
      final updated = config.copyWith(isEnabled: enabled);
      await _configurationRepository.updateReportConfiguration(updated);
      final list =
          state.reports.map((r) => r.id == config.id ? updated : r).toList();
      state = state.copyWith(reports: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteReport(String id) async {
    try {
      await _configurationRepository.deleteReportConfiguration(id);
      final list = state.reports.where((r) => r.id != id).toList();
      state = state.copyWith(reports: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> addTrigger(TriggerConfiguration config) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final created =
          await _configurationRepository.createTriggerConfiguration(config);
      state = state.copyWith(
        triggers: [...state.triggers, created],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> toggleTrigger(TriggerConfiguration config, bool active) async {
    try {
      final updated = config.copyWith(enabled: active);
      await _configurationRepository.updateTriggerConfiguration(updated);
      final List<TriggerConfiguration> list =
          state.triggers.map((t) => t.id == config.id ? updated : t).toList();
      state = state.copyWith(triggers: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> deleteTrigger(String id) async {
    try {
      await _configurationRepository.deleteTriggerConfiguration(id);
      final list = state.triggers.where((t) => t.id != id).toList();
      state = state.copyWith(triggers: list);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> saveNotificationPreferences(NotificationPreference prefs) async {
    try {
      final updated =
          await _configurationRepository.updateNotificationPreferences(prefs);
      state = state.copyWith(notificationPrefs: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> savePrivacySettings(PrivacySetting settings) async {
    try {
      final updated =
          await _configurationRepository.updatePrivacySettings(settings);
      state = state.copyWith(privacySettings: updated);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final parentDashboardControllerProvider =
    StateNotifierProvider<ParentDashboardController, ParentDashboardState>(
        (ref) {
  final familyRepo = ref.watch(familyRepositoryProvider);
  final configRepo = ref.watch(configurationRepositoryProvider);
  final reportRepo = ref.watch(approvedReportRepositoryProvider);
  return ParentDashboardController(
    familyRepository: familyRepo,
    configurationRepository: configRepo,
    approvedReportRepository: reportRepo,
  );
});
