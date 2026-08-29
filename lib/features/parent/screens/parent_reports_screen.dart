import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentReportsScreen extends ConsumerStatefulWidget {
  const ParentReportsScreen({super.key});

  @override
  ConsumerState<ParentReportsScreen> createState() =>
      _ParentReportsScreenState();
}

class _ParentReportsScreenState extends ConsumerState<ParentReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showReportConfigurationDialog() {
    final settingsRepo = ref.read(parentReportSettingsRepositoryProvider);
    final family = ref.read(parentDashboardControllerProvider).family;
    final familyId = family?.id ?? 'family-1';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return FutureBuilder<ParentReportSettings>(
          future: settingsRepo.getSettings(familyId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            var currentSettings = snapshot.data!;
            return StatefulBuilder(
              builder: (context, setModalState) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 24,
                    right: 24,
                    top: 24,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Report Settings',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.parentPrimary
                                    .withAlpha((0.1 * 255).round()),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Parent Admin',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.parentPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Configure scheduled wellbeing reports. Parent configurations take effect immediately without child approval.',
                          style: TextStyle(
                              color: AppTheme.neutralMuted, fontSize: 12),
                        ),
                        const Divider(height: 24),

                        // Reports Enabled Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Enable Wellbeing Reports',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'Receive periodic summaries of healthy digital balance'),
                          value: currentSettings.reportsEnabled,
                          activeThumbColor: AppTheme.parentPrimary,
                          onChanged: (val) {
                            setModalState(() {
                              currentSettings =
                                  currentSettings.copyWith(reportsEnabled: val);
                            });
                          },
                        ),

                        const SizedBox(height: 12),

                        // Frequency Dropdown
                        DropdownButtonFormField<ReportPeriod>(
                          initialValue: currentSettings.frequency,
                          decoration:
                              const InputDecoration(labelText: 'Report Frequency'),
                          items: const [
                            DropdownMenuItem(
                              value: ReportPeriod.daily,
                              child: Text('Daily Summary'),
                            ),
                            DropdownMenuItem(
                              value: ReportPeriod.weekly,
                              child: Text('Weekly Digest'),
                            ),
                            DropdownMenuItem(
                              value: ReportPeriod.monthly,
                              child: Text('Monthly Overview'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                currentSettings =
                                    currentSettings.copyWith(frequency: val);
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // Detail Level Dropdown
                        DropdownButtonFormField<ReportDetailLevel>(
                          initialValue: currentSettings.detail,
                          decoration:
                              const InputDecoration(labelText: 'Detail Level'),
                          items: const [
                            DropdownMenuItem(
                              value: ReportDetailLevel.summary,
                              child: Text('Summary (High-Level Metrics)'),
                            ),
                            DropdownMenuItem(
                              value: ReportDetailLevel.detailed,
                              child: Text('Detailed (Categories & Evidence)'),
                            ),
                            DropdownMenuItem(
                              value: ReportDetailLevel.insightsOnly,
                              child: Text('Insights Only (Habit Coaching)'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                currentSettings =
                                    currentSettings.copyWith(detail: val);
                              });
                            }
                          },
                        ),

                        const SizedBox(height: 16),

                        // Notifications Toggle
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Report Notifications',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text(
                              'Receive in-app notification when a new snapshot is generated'),
                          value: currentSettings.notificationsEnabled,
                          activeThumbColor: AppTheme.parentPrimary,
                          onChanged: (val) {
                            setModalState(() {
                              currentSettings = currentSettings.copyWith(
                                  notificationsEnabled: val);
                            });
                          },
                        ),

                        const Divider(height: 24),

                        // Configurable Sharing Categories
                        Text(
                          'Approved Sharing Categories',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Select which approved wellbeing metrics appear in reports. Raw child data is never accessible.',
                          style: TextStyle(
                              color: AppTheme.neutralMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 8),

                        ...ReportCategory.values.map((category) {
                          final isChecked =
                              currentSettings.categories.contains(category);
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(category.label,
                                style: const TextStyle(fontSize: 13)),
                            value: isChecked,
                            activeColor: AppTheme.parentPrimary,
                            onChanged: (bool? checked) {
                              final updated =
                                  Set<ReportCategory>.from(currentSettings.categories);
                              if (checked == true) {
                                updated.add(category);
                              } else {
                                updated.remove(category);
                              }
                              setModalState(() {
                                currentSettings = currentSettings.copyWith(
                                    categories: updated);
                              });
                            },
                          );
                        }),

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: () async {
                            await settingsRepo.updateSettings(
                                familyId, currentSettings);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Report settings updated successfully.'),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                              );
                              setState(() {});
                            }
                          },
                          child: const Text('Save Configuration'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showReportDetailModal(ApprovedReport report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.neutralBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with badges
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              report.formattedPeriodTitle,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Child: ${report.childNickname} • Detail: ${report.detailLevel.label}',
                              style: const TextStyle(
                                  color: AppTheme.neutralMuted, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen
                              .withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'IMMUTABLE SNAPSHOT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Privacy Version Info Banner
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.parentSurface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.neutralBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Privacy Filter: v${report.privacyFilterVersion}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.neutralMuted)),
                        Text('Context: v${report.contextVersion}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.neutralMuted)),
                        Text('Analytics: v${report.analyticsVersion}',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.neutralMuted)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Numerical Facts Grid
                  Text(
                    'Approved Factual Metrics',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Total Screen Time',
                          value: report.facts.formattedTotalTime,
                          subtitle:
                              '${report.facts.changePercentage >= 0 ? "+" : ""}${report.facts.changePercentage}% vs prior',
                          icon: Icons.timer_outlined,
                          color: AppTheme.parentPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Focus & Learning',
                          value: report.facts.formattedFocusTime,
                          subtitle:
                              '${report.facts.focusChangePercentage >= 0 ? "+" : ""}${report.facts.focusChangePercentage}% focus',
                          icon: Icons.psychology_alt_outlined,
                          color: AppTheme.parentSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Mindful Breaks',
                          value: '${report.facts.breakCount} pauses',
                          subtitle: 'Regular movement intervals',
                          icon: Icons.spa_outlined,
                          color: AppTheme.successGreen,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricTile(
                          title: 'Wellbeing Goals',
                          value:
                              '${report.facts.goalsCompletedCount}/${report.facts.goalsTotalCount}',
                          subtitle: 'Goals completed',
                          icon: Icons.flag_outlined,
                          color: AppTheme.warningOrange,
                        ),
                      ),
                    ],
                  ),

                  if (report.facts.categoryBreakdown.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Category Breakdown (Sanitized)',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          report.facts.categoryBreakdown.entries.map((entry) {
                        return Chip(
                          label: Text(
                              '${entry.key}: ${entry.value ~/ 60}h ${entry.value % 60}m',
                              style: const TextStyle(fontSize: 12)),
                          backgroundColor: AppTheme.parentSurface,
                          side: const BorderSide(color: AppTheme.neutralBorder),
                        );
                      }).toList(),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // Deterministic Factual Summary
                  Card(
                    color: AppTheme.parentSurface,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.fact_check_outlined,
                                  size: 16, color: AppTheme.parentSecondary),
                              SizedBox(width: 6),
                              Text(
                                'FACTUAL SUMMARY',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.parentPrimary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            report.summaryText,
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (report.insights.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text(
                      'Approved Insight Cards',
                      style:
                          Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 10),
                    ...report.insights.map((insight) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: insight.type == InsightType.fact
                                          ? AppTheme.parentSecondary
                                              .withAlpha((0.15 * 255).round())
                                          : AppTheme.successGreen
                                              .withAlpha((0.15 * 255).round()),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      insight.type.label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: insight.type == InsightType.fact
                                          ? AppTheme.parentSecondary
                                          : AppTheme.successGreen,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    insight.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                insight.description,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppTheme.childTextDark),
                              ),
                              if (insight.evidence != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.neutralBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Evidence: ${insight.evidence!.metric}',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                        '${insight.evidence!.currentValue} (was ${insight.evidence!.previousValue})',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.neutralMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  const SizedBox(height: 24),

                  // Ask AI Button
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      context.push(AppRoutes.parentAi);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.parentPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.psychology_rounded,
                        color: Colors.white),
                    label: const Text(
                      'Ask On-Device AI About This Report',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.parentTextDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.neutralMuted),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final reportRepo = ref.watch(approvedReportRepositoryProvider);

    final children = parentState.children;
    final activeChild = children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => children.isNotEmpty
          ? children.first
          : ChildProfile(
              id: 'child-1',
              nickname: 'Alex',
              age: 12,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approved Wellbeing Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Compare Reports',
            onPressed: () => context.push(AppRoutes.parentReportCompare),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Report Settings',
            onPressed: _showReportConfigurationDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AppTheme.parentPrimary,
            unselectedLabelColor: AppTheme.neutralMuted,
            indicatorColor: AppTheme.parentPrimary,
            tabs: const [
              Tab(text: 'Daily Summaries'),
              Tab(text: 'Weekly Digests'),
              Tab(text: 'Monthly Overviews'),
              Tab(text: 'Snapshot History'),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Multi-Child Selector Chips
          if (children.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  const Text('Child:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.neutralMuted)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: children.map((child) {
                          final isSelected = child.id == activeChild.id;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(child.nickname),
                              selected: isSelected,
                              selectedColor: AppTheme.parentPrimary
                                  .withAlpha((0.15 * 255).round()),
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() => _selectedChildId = child.id);
                                }
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Tab Views
          Expanded(
            child: FutureBuilder<List<ApprovedReport>>(
              future: reportRepo.getApprovedReports(activeChild.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports = snapshot.data ?? [];
                final dailyReports = reports
                    .where((r) => r.period == ReportPeriod.daily)
                    .toList();
                final weeklyReports = reports
                    .where((r) => r.period == ReportPeriod.weekly)
                    .toList();
                final monthlyReports = reports
                    .where((r) => r.period == ReportPeriod.monthly)
                    .toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportListView(dailyReports, 'daily summaries'),
                    _buildReportListView(weeklyReports, 'weekly digests'),
                    _buildReportListView(monthlyReports, 'monthly overviews'),
                    _buildReportListView(reports, 'snapshot history'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showReportConfigurationDialog,
        backgroundColor: AppTheme.parentPrimary,
        icon: const Icon(Icons.tune_rounded, color: Colors.white),
        label: const Text('Configure Reports',
            style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildReportListView(
      List<ApprovedReport> reports, String periodTitle) {
    if (reports.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assessment_outlined,
                  size: 48, color: AppTheme.neutralMuted),
              const SizedBox(height: 16),
              Text(
                'No $periodTitle available yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Approved reports are built entirely on the child device and synchronized securely without raw surveillance data.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.neutralMuted, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reports.length,
      itemBuilder: (context, index) {
        final report = reports[index];
        final changeSign = report.facts.changePercentage >= 0 ? '+' : '';

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showReportDetailModal(report),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.parentPrimary
                              .withAlpha((0.1 * 255).round()),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          report.period.label.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.parentPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${report.periodStart.month}/${report.periodStart.day} - ${report.periodEnd.month}/${report.periodEnd.day}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.neutralMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.facts.formattedTotalTime,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.parentTextDark,
                            ),
                          ),
                          const Text('Screen Time',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.neutralMuted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.facts.formattedFocusTime,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.parentSecondary,
                            ),
                          ),
                          const Text('Focus Learning',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.neutralMuted)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${report.facts.breakCount}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          const Text('Breaks',
                              style: TextStyle(
                                  fontSize: 11, color: AppTheme.neutralMuted)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    report.summaryText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.neutralMuted),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Change: $changeSign${report.facts.changePercentage}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: report.facts.changePercentage > 10
                              ? AppTheme.warningOrange
                              : AppTheme.successGreen,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              context.push(AppRoutes.parentAi);
                            },
                            icon: const Icon(Icons.psychology_rounded,
                                size: 16),
                            label: const Text('Ask AI',
                                style: TextStyle(fontSize: 12)),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              size: 18, color: AppTheme.neutralMuted),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
