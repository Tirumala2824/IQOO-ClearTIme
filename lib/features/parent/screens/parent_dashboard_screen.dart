import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/mission_model.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../../family/widgets/family_selector_dropdown.dart';
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
        body: AppLoadingState(message: 'Loading family dashboard...'),
      );
    }

    final children = parentState.children;
    if (children.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const FamilySelectorDropdown(),
        ),
        body: AppEmptyState(
          icon: Icons.family_restroom_rounded,
          title: 'No Children Linked Yet',
          description:
              'Pair your child\'s device securely using an invitation code or QR scan to start building mindful habits together.',
          actionLabel: 'Invite a Child Device',
          onAction: () => context.push(AppRoutes.parentInviteChild),
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

    final childTasks = parentState.parentTasks
        .where((t) => t.assignedToChildId == activeChild.id)
        .toList();
    final pendingReview = childTasks
        .where((t) => t.status == MissionStatus.submitted)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const FamilySelectorDropdown(),
        actions: [
          IconButton(
            icon: const Icon(Icons.compare_arrows_rounded),
            tooltip: 'Compare Reports',
            onPressed: () => context.push(AppRoutes.parentReportCompare),
          ),
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Invite Child',
            onPressed: () => context.push(AppRoutes.parentInviteChild),
          ),
          const SizedBox(width: 6),
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
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Welcome & Family Portal Banner
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.parentPrimary, AppColors.parentAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.parentPrimary.withAlpha((0.2 * 255).round()),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
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
                          'FAMILY WELLBEING OVERVIEW',
                          style: TextStyle(
                            color: Colors.white.withAlpha((0.85 * 255).round()),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Private & Local',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
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
                      'Aggregated Mindful Insights • Privacy Preserved',
                      style: TextStyle(
                        color: Colors.white.withAlpha((0.88 * 255).round()),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              // 2. Child Selector Pill Row
              if (children.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Children',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.parentTextDark,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => context.push(AppRoutes.parentInviteChild),
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Device'),
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
                          avatar: AppAvatar(
                            name: child.nickname,
                            radius: 12,
                            isSelected: false,
                          ),
                          label: Text(
                            child.nickname,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                              color: isSelected ? AppColors.parentPrimary : AppColors.parentTextDark,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.parentPrimary.withAlpha((0.15 * 255).round()),
                          backgroundColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? AppColors.parentPrimary : AppColors.neutralBorder,
                            width: isSelected ? 1.5 : 1.0,
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
                const SizedBox(height: 16),
              ],

              // 3. Pending Review Alert Banner (if child submitted proof)
              if (pendingReview.isNotEmpty) ...[
                AppCard(
                  backgroundColor: AppColors.warningOrangeLight,
                  borderColor: AppColors.warningOrange,
                  borderWidth: 1.5,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.pending_actions_rounded,
                            color: AppColors.warningOrange, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${pendingReview.length} Activity Pending Review',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: AppColors.parentTextDark,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${activeChild.nickname} submitted offline activity proof.',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.parentTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppButton(
                        label: 'Review',
                        size: AppButtonSize.sm,
                        customColor: AppColors.warningOrange,
                        onPressed: () => context.push(AppRoutes.parentTasks),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // 4. Wellbeing Metrics Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${activeChild.nickname}\'s Daily Balance',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.parentTextDark,
                          ),
                        ),
                        AppStatusBadge.success(label: '${history.streakDays}d Streak'),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            label: 'Screen Time',
                            value: childUsage != null && childUsage.totalMinutes > 0
                                ? childUsage.formattedTotalTime
                                : '0m',
                            icon: Icons.timer_outlined,
                            color: AppColors.parentPrimary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            label: 'Focus Time',
                            value: childUsage != null && childUsage.focusMinutes > 0
                                ? childUsage.formattedFocusTime
                                : '0m',
                            icon: Icons.bolt_rounded,
                            color: AppColors.successGreen,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildMetricTile(
                            context,
                            label: 'Breaks',
                            value: '${childUsage?.breakCount ?? 0}',
                            icon: Icons.self_improvement_rounded,
                            color: AppColors.warningOrange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 5. Offline Activities & Missions Card
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Real-World Activities',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.parentTextDark,
                          ),
                        ),
                        TextButton(
                          onPressed: () => context.push(AppRoutes.parentTasks),
                          child: Text('View All (${childTasks.length})'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (childTasks.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.park_outlined,
                                color: AppColors.parentPrimary, size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No offline missions assigned to ${activeChild.nickname} yet. Encourage family time, reading, or sports!',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.neutralMuted,
                                  height: 1.35,
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
                            color: AppColors.neutral50,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: task.status == MissionStatus.submitted
                                  ? AppColors.warningOrange
                                  : AppColors.neutralBorder,
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
                                        Text(
                                          task.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 14,
                                            color: AppColors.parentTextDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '(${task.targetMinutes}m)',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.neutralMuted,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (task.reward != null && task.reward!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        '🎁 ${task.reward}',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.warningOrange,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (task.status == MissionStatus.submitted)
                                AppStatusBadge.warning(label: 'Review')
                              else if (task.status == MissionStatus.approved)
                                AppStatusBadge.success(label: 'Done')
                              else
                                AppStatusBadge.primary(label: task.status.label),
                            ],
                          ),
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Assign Offline Activity',
                      icon: Icons.add_task_rounded,
                      isFullWidth: true,
                      size: AppButtonSize.md,
                      onPressed: () {
                        ParentCreateTaskDialog.show(
                          context,
                          children: parentState.children,
                          initialChildId: activeChild.id,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 6. AI Coaching Highlights & Goal Loop
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Mindful Coaching Loop',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.parentTextDark,
                          ),
                        ),
                        const Icon(Icons.psychology_outlined, color: AppColors.parentPrimary, size: 20),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (activeAiGoal != null) ...[
                      AppProgressBar(
                        progress: activeAiGoal.progressRatio,
                        label: 'Active AI Goal: ${activeAiGoal.title}',
                        valueText: '${activeAiGoal.currentMinutes}/${activeAiGoal.targetMinutes}m',
                        color: AppColors.parentPrimary,
                      ),
                    ] else ...[
                      const Text(
                        'Coaching loop active • Habits analyzed privately on-device.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.neutralMuted),
                      ),
                    ],
                    if (childSession != null && childSession.patterns.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.neutral100,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          children: [
                            Text(childSession.patterns.first.emoji, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                childSession.patterns.first.description,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.neutralBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.parentTextDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.neutralMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
