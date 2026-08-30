import '../../data/models/approved_report_model.dart';
import '../../data/models/report_config_model.dart';
import '../../data/models/usage_models.dart';
import '../../data/repositories/approved_report_repository.dart';
import '../storage/secure_local_usage_store.dart';
import 'approved_report_sync_service.dart';
import 'child_report_builder.dart';
import 'local_analytics_service.dart';
import 'report_request_service.dart';
import 'understand_act_report_builder.dart';

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
  final UnderstandActReportBuilder _understandActBuilder;
  final ApprovedReportSyncService? _syncService;

  // In-memory processed cache to enforce strict idempotency
  final Set<String> _processedScheduleKeys = {};

  ReportSchedulerService({
    required SecureLocalUsageStore usageStore,
    LocalAnalyticsService? analyticsService,
    ChildReportBuilder? reportBuilder,
    required ApprovedReportRepository reportRepo,
    UnderstandActReportBuilder? understandActBuilder,
    ApprovedReportSyncService? syncService,
  })  : _usageStore = usageStore,
        analyticsService = analyticsService ?? const LocalAnalyticsService(),
        _reportBuilder = reportBuilder ?? const ChildReportBuilder(),
        _reportRepo = reportRepo,
        _understandActBuilder =
            understandActBuilder ?? const UnderstandActReportBuilder(),
        _syncService = syncService;

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

    if (dailyAggregates.isEmpty) {
      return ScheduledReportResult(
        generated: false,
        reportKey: reportKey,
        status: 'UNAVAILABLE_NO_LOCAL_DATA',
      );
    }

    final List<DailyUsage> currentUsageList = dailyAggregates
        .map((agg) => DailyUsage(
              date: DateTime.tryParse(agg.dateString) ?? periodEnd,
              totalMinutes: agg.totalMinutes,
              // Focus is derived from the real coarse categories instead of
              // a fabricated percentage of total screen time.
              focusMinutes: (agg.categoryMinutes['Education'] ?? 0) +
                  (agg.categoryMinutes['Creativity'] ?? 0),
              unlockCount: agg.unlockCount,
              categoryMinutes: agg.categoryMinutes,
            ))
        .toList();

    // 4. Local Report Builder with Privacy Filter
    final allowedCategories = config.allowedCategories
        .map((cat) {
          return ReportCategory.values
                  .where((c) => c.name.toLowerCase() == cat.toLowerCase())
                  .firstOrNull ??
              ReportCategory.overallUsage;
        })
        .toSet();

    final settings = ParentReportSettings(categories: allowedCategories);
    final approvedReport = switch (periodEnum) {
      ReportPeriod.daily => _reportBuilder.buildDailyReport(
          childId: config.childId,
          childNickname: childNickname,
          familyId: config.familyId,
          date: periodStart,
          currentDaily: currentUsageList.last,
          settings: settings,
        ),
      ReportPeriod.weekly => _reportBuilder.buildWeeklyReport(
          childId: config.childId,
          childNickname: childNickname,
          familyId: config.familyId,
          weekStart: periodStart,
          weekEnd: periodEnd,
          dailyUsages: currentUsageList,
          settings: settings,
        ),
      ReportPeriod.monthly => _reportBuilder.buildMonthlyReport(
          childId: config.childId,
          childNickname: childNickname,
          familyId: config.familyId,
          year: periodStart.year,
          month: periodStart.month,
          totalMinutes: currentUsageList.fold(0, (sum, usage) => sum + usage.totalMinutes),
          totalFocusMinutes: currentUsageList.fold(0, (sum, usage) => sum + usage.focusMinutes),
          totalBreakCount: currentUsageList.fold(0, (sum, usage) => sum + usage.unlockCount),
          categoryDistribution: _aggregateCategories(currentUsageList),
          settings: settings,
        ),
    };

    // 5. Store approved report
    await _reportRepo.saveApprovedReport(approvedReport);
    _processedScheduleKeys.add(reportKey);

    await _syncService?.pushSnapshot(approvedReport);

    return ScheduledReportResult(
      generated: true,
      reportKey: reportKey,
      report: approvedReport,
      status: 'SUCCESS',
    );
  }

  /// Generates a real period report from stored local aggregates for a
  /// parent report request, in Understand → Act format, and pushes the
  /// filtered snapshot. Returns [ReportGenerationOutcome.unavailable] with a
  /// truthful reason when no local aggregates exist for the period.
  Future<ReportGenerationOutcome> generateForRequest({
    required String childId,
    required String childNickname,
    required String familyId,
    required ReportPeriod period,
  }) async {
    final now = DateTime.now();
    final current = <DailyAggregate>[];
    final previous = <DailyAggregate>[];

    final currentStart = _periodStart(period, now);
    final previousStart = _periodStart(period,
        currentStart.subtract(const Duration(days: 1)));
    final previousEnd =
        currentStart.subtract(const Duration(seconds: 1));

    current.addAll(await _usageStore.getDailyAggregatesInRange(
      _dateStr(currentStart),
      _dateStr(now),
    ));
    previous.addAll(await _usageStore.getDailyAggregatesInRange(
      _dateStr(previousStart),
      _dateStr(previousEnd),
    ));

    if (current.isEmpty) {
      return const ReportGenerationOutcome.unavailable(
        'No local activity was recorded for this period yet.',
      );
    }

    final sections = _understandActBuilder.build(
      current: current,
      previous: previous,
      localAiInterpretation: null,
    );

    final totalMinutes = current.fold<int>(0, (s, a) => s + a.totalMinutes);
    final focusMinutes = current.fold<int>(0, (s, a) => s + a.focusMinutes);
    final breakCount = current.fold<int>(0, (s, a) => s + a.breakCount);
    final currentUsages = current.map(_toDailyUsage).toList();

    final report = _reportBuilder.buildApprovedSnapshot(
      childId: childId,
      childNickname: childNickname,
      familyId: familyId,
      period: period,
      periodStart: currentStart,
      periodEnd: now,
      facts: ReportFacts(
        totalScreenMinutes: totalMinutes,
        previousScreenMinutes:
            previous.fold<int>(0, (s, a) => s + a.totalMinutes),
        focusMinutes: focusMinutes,
        previousFocusMinutes:
            previous.fold<int>(0, (s, a) => s + a.focusMinutes),
        breakCount: breakCount,
        previousBreakCount: previous.fold<int>(0, (s, a) => s + a.breakCount),
        categoryBreakdown: _aggregateCategories(currentUsages),
        screenUnlockCount: current.fold<int>(0, (s, a) => s + a.unlockCount),
      ),
      understandActSections: sections.toJson(),
    );

    await _reportRepo.saveApprovedReport(report);
    await _syncService?.pushSnapshot(report);

    return ReportGenerationOutcome.generated(report);
  }

  DailyUsage _toDailyUsage(DailyAggregate agg) => DailyUsage(
        date: DateTime.tryParse(agg.dateString) ?? DateTime.now(),
        totalMinutes: agg.totalMinutes,
        focusMinutes: agg.focusMinutes,
        unlockCount: agg.unlockCount,
        categoryMinutes: agg.categoryMinutes,
      );

  DateTime _periodStart(ReportPeriod period, DateTime anchor) {
    switch (period) {
      case ReportPeriod.daily:
        return DateTime(anchor.year, anchor.month, anchor.day);
      case ReportPeriod.weekly:
        final startOfWeek =
            anchor.subtract(Duration(days: anchor.weekday - 1));
        return DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      case ReportPeriod.monthly:
        return DateTime(anchor.year, anchor.month, 1);
    }
  }

  String _dateStr(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Clears schedule cache for resets or testing.
  void clearScheduleCache() {
    _processedScheduleKeys.clear();
  }

  Map<String, int> _aggregateCategories(List<DailyUsage> usages) {
    final totals = <String, int>{};
    for (final usage in usages) {
      usage.categoryMinutes.forEach((category, minutes) {
        totals[category] = (totals[category] ?? 0) + minutes;
      });
    }
    return totals;
  }
}
