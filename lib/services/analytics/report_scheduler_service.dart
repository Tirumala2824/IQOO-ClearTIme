import '../../data/models/approved_report_model.dart';
import '../../data/models/report_config_model.dart';
import '../../data/models/usage_models.dart';
import '../../data/repositories/approved_report_repository.dart';
import '../storage/secure_local_usage_store.dart';
import 'child_report_builder.dart';
import 'local_analytics_service.dart';

/// Result of an automated report scheduling job.
class ScheduledReportResult {
  final bool generated;
  final String reportKey;
  final ApprovedReport? report;
  final String status;

  const ScheduledReportResult({
    required this.generated,
    required this.reportKey,
    this.report,
    required this.status,
  });
}

/// ReportSchedulerService processes scheduled wellbeing reports independently
/// of UI lifecycle or timer state.
class ReportSchedulerService {
  final SecureLocalUsageStore _usageStore;
  final LocalAnalyticsService analyticsService;
  final ChildReportBuilder _reportBuilder;
  final ApprovedReportRepository _reportRepo;

  // In-memory processed cache to enforce strict idempotency
  final Set<String> _processedScheduleKeys = {};

  ReportSchedulerService({
    SecureLocalUsageStore? usageStore,
    LocalAnalyticsService? analyticsService,
    ChildReportBuilder? reportBuilder,
    ApprovedReportRepository? reportRepo,
  })  : _usageStore = usageStore ?? SecureLocalUsageStore(),
        analyticsService = analyticsService ?? const LocalAnalyticsService(),
        _reportBuilder = reportBuilder ?? const ChildReportBuilder(),
        _reportRepo = reportRepo ?? InMemoryApprovedReportRepository();

  /// Generates a unique, deterministic idempotency key for the scheduled report.
  String generateDeterministicReportKey({
    required String familyId,
    required String childId,
    required ReportPeriod period,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) {
    final startKey = '${periodStart.year}-${periodStart.month}-${periodStart.day}';
    final endKey = '${periodEnd.year}-${periodEnd.month}-${periodEnd.day}';
    return '${familyId}_${childId}_${period.name}_${startKey}_$endKey';
  }

  /// Evaluates and generates a scheduled report if due and not yet processed.
  Future<ScheduledReportResult> processReportSchedule({
    required ReportConfiguration config,
    required String childNickname,
    DateTime? executionTime,
  }) async {
    final now = executionTime ?? DateTime.now();

    // Determine period dates based on configuration
    final DateTime periodStart;
    final DateTime periodEnd = now;

    switch (config.frequency) {
      case ReportFrequency.daily:
        periodStart = DateTime(now.year, now.month, now.day);
        break;
      case ReportFrequency.monthly:
        periodStart = now.subtract(const Duration(days: 30));
        break;
      case ReportFrequency.weekly:
        periodStart = now.subtract(const Duration(days: 7));
        break;
    }

    final periodEnum = config.frequency == ReportFrequency.daily
        ? ReportPeriod.daily
        : (config.frequency == ReportFrequency.monthly
            ? ReportPeriod.monthly
            : ReportPeriod.weekly);

    final reportKey = generateDeterministicReportKey(
      familyId: config.familyId,
      childId: config.childId,
      period: periodEnum,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );

    // 1. Idempotency Check: Don't process twice
    if (_processedScheduleKeys.contains(reportKey)) {
      return ScheduledReportResult(
        generated: false,
        reportKey: reportKey,
        status: 'SKIPPED_ALREADY_PROCESSED',
      );
    }

    // 2. Check if report already exists in repository
    final existingReports = await _reportRepo.getApprovedReports(config.childId);
    final isAlreadySaved = existingReports.any((r) =>
        r.period == periodEnum &&
        r.periodStart.year == periodStart.year &&
        r.periodStart.month == periodStart.month &&
        r.periodStart.day == periodStart.day);

    if (isAlreadySaved) {
      _processedScheduleKeys.add(reportKey);
      return ScheduledReportResult(
        generated: false,
        reportKey: reportKey,
        status: 'SKIPPED_EXISTING_RECORD',
      );
    }

    // 3. Child Local Analytics aggregation
    final startStr =
        '${periodStart.year.toString().padLeft(4, '0')}-${periodStart.month.toString().padLeft(2, '0')}-${periodStart.day.toString().padLeft(2, '0')}';
    final endStr =
        '${periodEnd.year.toString().padLeft(4, '0')}-${periodEnd.month.toString().padLeft(2, '0')}-${periodEnd.day.toString().padLeft(2, '0')}';

    final dailyAggregates =
        await _usageStore.getDailyAggregatesInRange(startStr, endStr);

    final List<DailyUsage> currentUsageList = dailyAggregates.isNotEmpty
        ? dailyAggregates
            .map((agg) => DailyUsage(
                  date: DateTime.tryParse(agg.dateString) ?? DateTime.now(),
                  totalMinutes: agg.totalMinutes,
                  focusMinutes: (agg.totalMinutes * 0.4).toInt(),
                  unlockCount: agg.unlockCount,
                  categoryMinutes: agg.categoryMinutes,
                ))
            .toList()
        : [
            DailyUsage(
              date: periodEnd,
              totalMinutes: 140,
              focusMinutes: 60,
              unlockCount: 18,
              categoryMinutes: const {
                'Learning': 60,
                'Utilities': 50,
                'Entertainment': 30,
              },
            )
          ];

    // 4. Local Report Builder with Privacy Filter
    final allowedCategories = config.allowedCategories
        .map((cat) {
          return ReportCategory.values.firstWhere(
            (c) => c.name.toLowerCase() == cat.toLowerCase(),
            orElse: () => ReportCategory.overallUsage,
          );
        })
        .toSet();

    final approvedReport = _reportBuilder.buildWeeklyReport(
      childId: config.childId,
      childNickname: childNickname,
      familyId: config.familyId,
      weekStart: periodStart,
      weekEnd: periodEnd,
      dailyUsages: currentUsageList,
      settings: ParentReportSettings(
        categories: allowedCategories.isNotEmpty
            ? allowedCategories
            : const {
                ReportCategory.overallUsage,
                ReportCategory.usageTrend,
                ReportCategory.focusTime,
                ReportCategory.goals,
                ReportCategory.achievements,
              },
      ),
    );

    // 5. Store approved report
    await _reportRepo.saveApprovedReport(approvedReport);
    _processedScheduleKeys.add(reportKey);

    return ScheduledReportResult(
      generated: true,
      reportKey: reportKey,
      report: approvedReport,
      status: 'SUCCESS',
    );
  }

  /// Clears schedule cache for resets or testing.
  void clearScheduleCache() {
    _processedScheduleKeys.clear();
  }
}
