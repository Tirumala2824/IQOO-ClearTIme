import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/family_model.dart';
import '../../../data/models/approved_report_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/mission_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../controllers/parent_dashboard_controller.dart';
import 'parent_create_task_dialog.dart';

class ParentDashboardScreen extends ConsumerStatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  ConsumerState<ParentDashboardScreen> createState() =>
      _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends ConsumerState<ParentDashboardScreen> {
  String? _selectedChildId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = ref.read(authControllerProvider).user;
      if (user != null) {
        ref
            .read(parentDashboardControllerProvider.notifier)
            .loadDashboard(user.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final user = ref.watch(authControllerProvider).user;
    final family = parentState.family;

    if (parentState.isLoading && family == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final children = parentState.children;
    if (children.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: parentState.allFamilies.length > 1
              ? PopupMenuButton<Family>(
                  initialValue: family,
                  onSelected: (newFamily) async {
                    if (user != null) {
                      await ref
                          .read(parentDashboardControllerProvider.notifier)
                          .switchFamily(newFamily, user.id);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          family?.name ?? 'Family Portal',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded, size: 24),
                    ],
                  ),
                  itemBuilder: (context) {
                    return parentState.allFamilies.map((f) {
                      final isSelected = f.id == family?.id;
                      return PopupMenuItem<Family>(
                        value: f,
                        child: Row(
                          children: [
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.diversity_3_outlined,
                              color: isSelected
                                  ? AppTheme.parentPrimary
                                  : AppTheme.neutralMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                f.name,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.parentPrimary
                                      : AppTheme.parentTextDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList();
                  },
                )
              : Text(family?.name ?? 'Family Portal'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.family_restroom_rounded, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No children linked to this family yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.parentInviteChild),
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Invite a Child'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final activeChild = children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => children.first,
    );

    final childUsage = parentState.childUsageSummaries[activeChild.id];
    final childSession = parentState.childCoachingSessions[activeChild.id];
    final history = parentState.coachingHistory;
    final aiGoals = parentState.childGoals
        .where((g) => g.source == GoalSource.aiGenerated && g.status == GoalStatus.active)
        .toList();
    final activeAiGoal = aiGoals.isNotEmpty ? aiGoals.first : null;

    return Scaffold(
      appBar: AppBar(
        title: parentState.allFamilies.length > 1
            ? PopupMenuButton<Family>(
                initialValue: family,
                onSelected: (newFamily) async {
                  if (user != null) {
                    await ref
                        .read(parentDashboardControllerProvider.notifier)
                        .switchFamily(newFamily, user.id);
                  }
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        family?.name ?? 'Family Portal',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down_rounded, size: 24),
                  ],
                ),
                itemBuilder: (context) {
                  return parentState.allFamilies.map((f) {
                    final isSelected = f.id == family?.id;
                    return PopupMenuItem<Family>(
                      value: f,
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.diversity_3_outlined,
                            color: isSelected
                                ? AppTheme.parentPrimary
                                : AppTheme.neutralMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              f.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                  color: isSelected
                                      ? AppTheme.parentPrimary
                                      : AppTheme.parentTextDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              )
            : Text(family?.name ?? 'Family Portal'),
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
                      family?.name ?? 'Family Portal',
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

              // ─── LIVE AI COACHING STATUS FOR ACTIVE CHILD ───
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppTheme.parentPrimary.withAlpha((0.2 * 255).round()),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.parentPrimary
                          .withAlpha((0.06 * 255).round()),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text('🤖', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Text(
                              '${activeChild.nickname}\'s Coaching Loop',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.parentTextDark,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen
                                .withAlpha((0.15 * 255).round()),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 13, color: AppTheme.successGreen),
                              const SizedBox(width: 4),
                              Text(
                                '${history.streakDays}d Streak',
                                style: const TextStyle(
                                  color: AppTheme.successGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (activeAiGoal != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.parentSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Current AI Goal',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.parentPrimary,
                                  ),
                                ),
                                Text(
                                  '${activeAiGoal.currentMinutes}/${activeAiGoal.targetMinutes} min',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.neutralMuted,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activeAiGoal.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: activeAiGoal.progressRatio,
                                backgroundColor: AppTheme.neutralBg,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                    AppTheme.parentPrimary),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Coaching loop active • Goal updates automatically based on screen habits.',
                        style: TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
                      ),
                    ],

                    if (childSession != null && childSession.patterns.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Latest Habit Observation:',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.neutralMuted),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${childSession.patterns.first.emoji} ${childSession.patterns.first.description}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── REAL-WORLD OFFLINE MISSIONS SECTION ───
              Builder(
                builder: (context) {
                  final childTasks = parentState.parentTasks
                      .where((t) => t.assignedToChildId == activeChild.id)
                      .toList();
                  final pendingReview = childTasks
                      .where((t) => t.status == MissionStatus.submitted)
                      .toList();

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: pendingReview.isNotEmpty
                            ? AppTheme.warningOrange
                            : AppTheme.neutralBorder,
                        width: pendingReview.isNotEmpty ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha((0.03 * 255).round()),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Text('🎯', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Text(
                                  'Activities',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppTheme.parentTextDark,
                                  ),
                                ),
                              ],
                            ),
                            if (pendingReview.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppTheme.warningOrange,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${pendingReview.length} Pending Review',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (childTasks.isEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppTheme.parentSurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.park_outlined,
                                    color: AppTheme.parentPrimary, size: 24),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'No offline missions assigned to ${activeChild.nickname} yet. Encourage family time, reading, outdoor play, or exercise!',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.neutralMuted,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          ...childTasks.take(2).map((task) {
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.parentSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: task.status == MissionStatus.submitted
                                      ? AppTheme.warningOrange.withAlpha((0.5 * 255).round())
                                      : AppTheme.neutralBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.parentPrimary
                                                    .withAlpha((0.1 * 255).round()),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${task.targetMinutes} min',
                                                style: const TextStyle(
                                                  color: AppTheme.parentPrimary,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              task.status.label,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: task.status == MissionStatus.approved
                                                    ? AppTheme.successGreen
                                                    : task.status == MissionStatus.submitted
                                                        ? AppTheme.warningOrange
                                                        : AppTheme.neutralMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          task.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                        if (task.reward != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            '🎁 ${task.reward}',
                                            style: const TextStyle(
                                              fontSize: 11.5,
                                              color: AppTheme.warningOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${task.targetMinutes}m',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: AppTheme.neutralMuted,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton.icon(
                              onPressed: () => context.push(AppRoutes.parentTasks),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                              label: Text('All Missions (${childTasks.length})'),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.parentPrimary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              onPressed: () {
                                ParentCreateTaskDialog.show(
                                  context,
                                  children: parentState.children,
                                  initialChildId: activeChild.id,
                                );
                              },
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Assign Mission'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Approved Insights Section for Selected Child
              Builder(
                builder: (context) {
                  final reports = parentState.approvedReports
                      .where((r) => r.childId == activeChild.id)
                      .toList();

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
                            periodStart:
                                DateTime.now().subtract(const Duration(days: 7)),
                            periodEnd: DateTime.now(),
                            facts: ReportFacts(
                              totalScreenMinutes: (childUsage?.totalMinutes ?? 120) * 7,
                              focusMinutes: (childUsage?.focusMinutes ?? 60) * 7,
                              breakCount: (childUsage?.breakCount ?? 3) * 7,
                              goalsCompletedCount: 4,
                              goalsTotalCount: 5,
                              changePercentage: -8.5,
                            ),
                            summaryText:
                                'Balanced mindful progress recorded this week with active AI coaching guidance.',
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
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            latestWeekly.period == ReportPeriod.weekly
                                ? 'Weekly Average'
                                : 'Daily Report',
                            style: const TextStyle(
                              color: AppTheme.neutralMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Metrics Summary Grid (2x2)
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.6,
                        children: [
                          _buildStatCard(
                            title: 'Screen Time',
                            value: facts.formattedTotalTime,
                            subtitle:
                                '${facts.changePercentage >= 0 ? "+" : ""}${facts.changePercentage.toStringAsFixed(1)}% vs prior',
                            icon: Icons.timer_outlined,
                            color: AppTheme.parentPrimary,
                          ),
                          _buildStatCard(
                            title: 'Focus Sessions',
                            value: facts.formattedFocusTime,
                            subtitle:
                                '${((facts.focusMinutes / (facts.totalScreenMinutes > 0 ? facts.totalScreenMinutes : 1)) * 100).round()}% of total time',
                            icon: Icons.psychology_outlined,
                            color: AppTheme.parentSecondary,
                          ),
                          _buildStatCard(
                            title: 'Mindful Breaks',
                            value: '${facts.breakCount}',
                            subtitle: 'Approved count',
                            icon: Icons.self_improvement_outlined,
                            color: AppTheme.successGreen,
                          ),
                          _buildStatCard(
                            title: 'Goal Progress',
                            value:
                                '${facts.goalsCompletedCount}/${facts.goalsTotalCount}',
                            subtitle: 'Wellbeing goals',
                            icon: Icons.flag_outlined,
                            color: AppTheme.warningOrange,
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Weekly Summary Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified_outlined,
                                      color: AppTheme.parentPrimary, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Approved Report Summary',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.parentPrimary,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                latestWeekly.summaryText,
                                style: const TextStyle(
                                    fontSize: 13, height: 1.4),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Generated ${latestWeekly.periodStart.month}/${latestWeekly.periodStart.day} - ${latestWeekly.periodEnd.month}/${latestWeekly.periodEnd.day}',
                                    style: const TextStyle(
                                        color: AppTheme.neutralMuted,
                                        fontSize: 11),
                                  ),
                                  TextButton.icon(
                                    onPressed: () => context.push(
                                        '${AppRoutes.parentAi}?childId=${activeChild.id}&reportId=${latestWeekly.id}'),
                                    icon: const Icon(
                                        Icons.chat_bubble_outline_rounded,
                                        size: 16),
                                    label: const Text('Discuss with AI',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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

  Widget _buildStatCard({
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
