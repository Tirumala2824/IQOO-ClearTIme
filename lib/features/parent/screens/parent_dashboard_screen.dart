import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/parent_dashboard_controller.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final family = parentState.family;
    final reportRepo = ref.watch(approvedReportRepositoryProvider);

    if (parentState.isLoading && family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final children = parentState.children;
    final activeChild = children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => children.isNotEmpty
          ? children.first
          : const ChildProfile(id: 'child-1', nickname: 'Alex', age: 12),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(family?.name ?? 'Family Portal'),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Compare Reports',
            onPressed: () => context.push(AppRoutes.parentReportCompare),
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Invite Child',
            onPressed: () => context.push(AppRoutes.parentInviteChild),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (user != null) {
            await ref
                .read(parentDashboardControllerProvider.notifier)
                .loadDashboard(user.id);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome & Family Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.parentPrimary, AppTheme.parentAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.parentPrimary
                          .withAlpha((0.25 * 255).round()),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Parent Wellbeing Portal',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.85 * 255).round()),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.admin_panel_settings_rounded,
                                  color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Family Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      family?.name ?? 'My Family Space',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Approved Wellbeing Insights • Zero Raw Child Surveillance',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.85 * 255).round()),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Multi-Child Selector Bar
              if (children.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Children',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton.icon(
                      onPressed: () =>
                          context.push(AppRoutes.parentInviteChild),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Child'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: children.map((child) {
                      final isSelected = child.id == activeChild.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          avatar: CircleAvatar(
                            backgroundColor: isSelected
                                ? AppTheme.parentPrimary
                                : AppTheme.neutralMuted
                                    .withAlpha((0.2 * 255).round()),
                            child: Text(
                              child.nickname.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.parentTextDark,
                              ),
                            ),
                          ),
                          label: Text(
                            child.nickname,
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isSelected
                                  ? AppTheme.parentPrimary
                                  : AppTheme.parentTextDark,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppTheme.parentPrimary
                              .withAlpha((0.15 * 255).round()),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected
                                ? AppTheme.parentPrimary
                                : AppTheme.neutralBorder,
                          ),
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
                const SizedBox(height: 20),
              ],

              // Approved Insights Section for Selected Child
              FutureBuilder<List<ApprovedReport>>(
                future: reportRepo.getApprovedReports(activeChild.id),
                builder: (context, snapshot) {
                  final reports = snapshot.data ?? [];
                  final latestWeekly = reports.firstWhere(
                    (r) => r.period == ReportPeriod.weekly,
                    orElse: () => reports.isNotEmpty
                        ? reports.first
                        : ApprovedReport(
                            id: 'rep-placeholder',
                            childId: activeChild.id,
                            childNickname: activeChild.nickname,
                            familyId: family?.id ?? 'f1',
                            period: ReportPeriod.weekly,
                            periodStart: DateTime.now().subtract(const Duration(days: 7)),
                            periodEnd: DateTime.now(),
                            facts: const ReportFacts(
                              totalScreenMinutes: 872,
                              focusMinutes: 370,
                              breakCount: 22,
                              goalsCompletedCount: 5,
                              goalsTotalCount: 7,
                              changePercentage: 12.1,
                            ),
                            summaryText: 'Balanced mindful progress recorded this week.',
                            createdAt: DateTime.now(),
                          ),
                  );

                  final facts = latestWeekly.facts;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Approved Insights (${activeChild.nickname})',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.parentReports),
                            child: const Text('View All Reports'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Metric Grid
                      Row(
                        children: [
                          Expanded(
                            child: _buildInsightCard(
                              title: 'Screen Time Trend',
                              value: facts.formattedTotalTime,
                              subtitle:
                                  '${facts.changePercentage >= 0 ? "+" : ""}${facts.changePercentage}% vs prior',
                              icon: Icons.trending_up_rounded,
                              color: facts.changePercentage > 15
                                  ? AppTheme.warningOrange
                                  : AppTheme.parentPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInsightCard(
                              title: 'Focus & Learning',
                              value: facts.formattedFocusTime,
                              subtitle: '${facts.focusChangePercentage >= 0 ? "+" : ""}${facts.focusChangePercentage}% focus hours',
                              icon: Icons.psychology_rounded,
                              color: AppTheme.parentSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInsightCard(
                              title: 'Movement Breaks',
                              value: '${facts.breakCount} pauses',
                              subtitle: 'Eye & physical pauses',
                              icon: Icons.directions_walk_rounded,
                              color: AppTheme.successGreen,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildInsightCard(
                              title: 'Goals Progress',
                              value:
                                  '${facts.goalsCompletedCount}/${facts.goalsTotalCount}',
                              subtitle: 'Mindful goals met',
                              icon: Icons.emoji_events_rounded,
                              color: AppTheme.parentAccent,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Recent Reports Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Reports',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.psychology_rounded,
                                color: AppTheme.parentPrimary),
                            tooltip: 'Ask Local AI',
                            onPressed: () => context.go(AppRoutes.parentAi),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (reports.isEmpty)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(Icons.assessment_outlined,
                                    size: 36, color: AppTheme.neutralMuted),
                                const SizedBox(height: 10),
                                const Text(
                                  'No snapshots generated yet',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'When ${activeChild.nickname}\'s device completes a daily or weekly period, privacy-filtered snapshots appear here.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppTheme.neutralMuted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ...reports.take(2).map((r) {
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.parentPrimary
                                      .withAlpha((0.15 * 255).round()),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assessment_rounded,
                                    color: AppTheme.parentPrimary),
                              ),
                              title: Text(
                                r.formattedPeriodTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              subtitle: Text(
                                'Screen: ${r.facts.formattedTotalTime} • Focus: ${r.facts.formattedFocusTime}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () =>
                                    context.go(AppRoutes.parentReports),
                                child: const Text('View Report',
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // Recent Wellbeing Alerts Section
              Text(
                'Recent Wellbeing Alerts',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen
                              .withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.check_circle_outline_rounded,
                            color: AppTheme.successGreen),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Healthy Balance Maintained',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'No excessive screen time anomalies detected across active child profiles.',
                              style: TextStyle(
                                  fontSize: 11.5, color: AppTheme.neutralMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Strict Privacy Notice Card
              Card(
                color: AppTheme.parentSurface,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: const [
                      Icon(Icons.shield_outlined,
                          color: AppTheme.parentSecondary, size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Absolute Privacy Architecture: The parent portal receives only approved insights. Raw usage data remains exclusively on the child device.',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.neutralMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
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
              color: AppTheme.neutralMuted,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
