import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/goal_model.dart';
import '../controllers/child_dashboard_controller.dart';
import '../controllers/child_goals_controller.dart';
import '../controllers/child_missions_controller.dart';
import 'child_task_submission_dialog.dart';

class ChildGoalsScreen extends ConsumerStatefulWidget {
  const ChildGoalsScreen({super.key});

  @override
  ConsumerState<ChildGoalsScreen> createState() => _ChildGoalsScreenState();
}

class _ChildGoalsScreenState extends ConsumerState<ChildGoalsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(childGoalsControllerProvider.notifier).loadGoals();
      final profile = ref.read(childDashboardControllerProvider).profile;
      ref
          .read(childMissionsControllerProvider.notifier)
          .loadMissions(childId: profile?.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalsState = ref.watch(childGoalsControllerProvider);
    final missionsState = ref.watch(childMissionsControllerProvider);
    final activeGoals = goalsState.activeGoals;
    final historyGoals = goalsState.completedGoals;

    return Scaffold(
      backgroundColor: AppColors.childSurface,
      appBar: AppBar(
        backgroundColor: AppColors.childSurface,
        title: const Text(
          'Goals & Activities',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: AppColors.childTextDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.childPrimary,
          indicatorWeight: 3,
          labelColor: AppColors.childPrimary,
          unselectedLabelColor: AppColors.neutralMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [
            Tab(text: 'Active (${activeGoals.length + missionsState.activeMissions.length})'),
            Tab(text: 'Completed (${historyGoals.length + missionsState.completedCount})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.childSecondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showAddGoalDialog(context, ref),
      ),
      body: goalsState.isLoading
          ? const AppLoadingState(message: 'Loading goals & activities...')
          : TabBarView(
              controller: _tabController,
              children: [
                // TAB 1: ACTIVE GOALS & DAILY ACTIVITIES
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(childGoalsControllerProvider.notifier).loadGoals();
                    final profile = ref.read(childDashboardControllerProvider).profile;
                    await ref.read(childMissionsControllerProvider.notifier).loadMissions(childId: profile?.id);
                  },
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                    children: [
                      // Active Goals Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Focus Goals',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.childTextDark,
                            ),
                          ),
                          Text(
                            '${activeGoals.length} in progress',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.neutralMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (activeGoals.isEmpty)
                        AppEmptyState(
                          icon: Icons.track_changes_rounded,
                          title: 'No active goals yet',
                          description: 'Tap "+ New Goal" below to set your next mindful focus challenge!',
                          iconColor: AppColors.childSecondary,
                        )
                      else
                        ...activeGoals.map((goal) => _buildGoalCard(context, ref, goal)),

                      const SizedBox(height: 24),

                      // Daily Activities Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Offline Activities',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.childTextDark,
                            ),
                          ),
                          Text(
                            '${missionsState.completedCount}/${missionsState.missions.length} done',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.childSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (missionsState.missions.isEmpty)
                        AppEmptyState(
                          icon: Icons.nature_people_rounded,
                          title: 'No missions right now',
                          description: 'Your parent hasn\'t assigned a new mission. Enjoy your offline moments!',
                          iconColor: AppColors.childSecondary,
                        )
                      else
                        ...missionsState.missions.map((mission) {
                          final isDone = mission.isCompleted;
                          final isPending = mission.isPendingApproval;
                          final isStarted = mission.isStarted;

                          return AppCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            borderColor: isDone
                                ? AppColors.childSecondary
                                : isPending
                                    ? AppColors.warningOrange
                                    : isStarted
                                        ? AppColors.childPrimary
                                        : AppColors.neutralBorder,
                            borderWidth: isDone || isPending || isStarted ? 1.5 : 1.0,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.childPrimary.withAlpha((0.12 * 255).round()),
                                        borderRadius: BorderRadius.circular(AppRadius.xs),
                                      ),
                                      child: Text(
                                        '${mission.targetMinutes} min',
                                        style: const TextStyle(
                                          color: AppColors.childPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (isDone)
                                      AppStatusBadge.success(label: 'Done')
                                    else if (isPending)
                                      AppStatusBadge.warning(label: 'Pending Review')
                                    else if (isStarted)
                                      const AppStatusBadge(label: 'In Progress', type: AppStatusType.info)
                                    else
                                      AppStatusBadge.primary(label: 'Assigned'),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  mission.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    decoration: isDone ? TextDecoration.lineThrough : null,
                                    color: AppColors.childTextDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mission.description,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.childTextSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                if (mission.reward != null && mission.reward!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.warningOrangeLight,
                                      borderRadius: BorderRadius.circular(AppRadius.xs),
                                    ),
                                    child: Text(
                                      '🎁 Reward: ${mission.reward}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.warningOrange,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                                if (mission.isNeedsRetry && mission.parentFeedback != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    'Parent note: "${mission.parentFeedback}"',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.warningOrange,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Target: ${mission.targetMinutes} mins',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.neutralMuted,
                                      ),
                                    ),
                                    if (isDone)
                                      const Text(
                                        'Completed 🎉',
                                        style: TextStyle(
                                          color: AppColors.successGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      )
                                    else if (isPending)
                                      const Text(
                                        'Waiting for Parent ⏳',
                                        style: TextStyle(
                                          color: AppColors.warningOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      )
                                    else if (isStarted)
                                      AppButton(
                                        label: 'Complete & Submit',
                                        size: AppButtonSize.sm,
                                        variant: AppButtonVariant.secondary,
                                        onPressed: () {
                                          ChildTaskSubmissionDialog.show(
                                            context,
                                            mission: mission,
                                          );
                                        },
                                      )
                                    else
                                      AppButton(
                                        label: mission.isNeedsRetry ? 'Try Again' : 'Start Activity',
                                        size: AppButtonSize.sm,
                                        variant: AppButtonVariant.primary,
                                        onPressed: () {
                                          ref
                                              .read(childMissionsControllerProvider.notifier)
                                              .startTask(mission.id);
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),

                // TAB 2: COMPLETED GOALS HISTORY
                RefreshIndicator(
                  onRefresh: () => ref.read(childGoalsControllerProvider.notifier).loadGoals(),
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 14.0),
                    children: [
                      if (historyGoals.isEmpty)
                        const AppEmptyState(
                          icon: Icons.emoji_events_outlined,
                          title: 'No completed goals yet',
                          description: 'Complete goals and activities to build your habit achievements history!',
                        )
                      else
                        ...historyGoals.map((goal) => _buildGoalCard(context, ref, goal)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, ChildGoal goal) {
    final isDone = goal.isCompleted;
    final isPaused = goal.status == GoalStatus.paused;
    final isAI = goal.isAIGenerated;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      borderColor: isDone
          ? AppColors.childSecondary
          : isAI
              ? AppColors.childPrimary.withAlpha((0.3 * 255).round())
              : AppColors.neutralBorder,
      borderWidth: isDone || isAI ? 1.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _getGoalColor(goal.type).withAlpha((0.15 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      _getGoalTypeLabel(goal.type),
                      style: TextStyle(
                        color: _getGoalColor(goal.type),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (isAI) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.childPrimary.withAlpha((0.15 * 255).round()),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Text(
                        'AI Recommended',
                        style: TextStyle(
                          color: AppColors.childPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  if (!isDone)
                    IconButton(
                      icon: Icon(
                        isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                        color: AppColors.neutralMuted,
                        size: 20,
                      ),
                      tooltip: isPaused ? 'Resume Goal' : 'Pause Goal',
                      onPressed: () {
                        ref
                            .read(childGoalsControllerProvider.notifier)
                            .toggleGoalPause(goal.id);
                      },
                    ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.neutralMuted,
                      size: 20,
                    ),
                    tooltip: 'Delete Goal',
                    onPressed: () => _confirmDeleteGoal(context, ref, goal.id),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            goal.title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15.5,
              decoration: isDone ? TextDecoration.lineThrough : null,
              color: isPaused ? AppColors.neutralMuted : AppColors.childTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            goal.description,
            style: const TextStyle(fontSize: 13, color: AppColors.neutralMuted),
          ),

          const SizedBox(height: 12),

          AppProgressBar(
            progress: goal.progressRatio,
            label: '${goal.currentMinutes}/${goal.targetMinutes} ${goal.type == GoalType.breakGoal ? "breaks" : "min"}',
            valueText: isDone
                ? 'Completed 🎉'
                : isPaused
                    ? 'Paused'
                    : '${goal.progressPercentage}%',
            color: isDone
                ? AppColors.childSecondary
                : isPaused
                    ? AppColors.neutralMuted
                    : _getGoalColor(goal.type),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteGoal(BuildContext context, WidgetRef ref, String goalId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete Goal?'),
        content: const Text('Are you sure you want to remove this wellbeing goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
            ),
            onPressed: () {
              ref.read(childGoalsControllerProvider.notifier).deleteGoal(goalId);
              Navigator.pop(ctx);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog(BuildContext context, WidgetRef ref) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final targetCtrl = TextEditingController(text: '30');
    GoalType selectedType = GoalType.dailyFocus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xxl)),
          title: const Text('Create Focus Goal 🎯', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: titleCtrl,
                  label: 'Goal Title *',
                  hint: 'e.g. Daily Reading Focus',
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: descCtrl,
                  label: 'Description',
                  hint: 'What would you like to achieve?',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Goal Type',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<GoalType>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  items: GoalType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(_getGoalTypeLabel(t), style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  label: selectedType == GoalType.breakGoal ? 'Target Breaks (count)' : 'Target Minutes',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            AppButton(
              label: 'Create Goal',
              size: AppButtonSize.sm,
              variant: AppButtonVariant.secondary,
              onPressed: () {
                if (titleCtrl.text.isNotEmpty) {
                  final target = int.tryParse(targetCtrl.text) ?? 30;
                  ref.read(childGoalsControllerProvider.notifier).createGoal(
                        title: titleCtrl.text,
                        description: descCtrl.text,
                        type: selectedType,
                        targetMinutes: target,
                      );
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _getGoalColor(GoalType type) {
    switch (type) {
      case GoalType.dailyFocus:
        return AppColors.childPrimary;
      case GoalType.weeklyFocus:
        return AppColors.childSecondary;
      case GoalType.breakGoal:
        return AppColors.warningOrange;
      case GoalType.digitalBalance:
        return AppColors.parentAccent;
    }
  }

  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.dailyFocus:
        return 'Daily Focus';
      case GoalType.weeklyFocus:
        return 'Weekly Target';
      case GoalType.breakGoal:
        return 'Mindful Break';
      case GoalType.digitalBalance:
        return 'Digital Balance';
    }
  }
}
