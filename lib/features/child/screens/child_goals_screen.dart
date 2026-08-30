import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/goal_model.dart';
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
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        elevation: 0,
        title: const Text(
          'Goals & Activities 🎯',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppTheme.childTextDark,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.childPrimary,
          indicatorWeight: 3,
          labelColor: AppTheme.childPrimary,
          unselectedLabelColor: AppTheme.neutralMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: 'Active (${activeGoals.length})'),
            Tab(text: 'Completed (${historyGoals.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.childSecondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddGoalDialog(context, ref),
      ),
      body: goalsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // ─── TAB 1: ACTIVE GOALS & DAILY QUESTS ───
                RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(childGoalsControllerProvider.notifier).loadGoals();
                    await ref.read(childMissionsControllerProvider.notifier).loadMissions();
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
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
                              color: AppTheme.childTextDark,
                            ),
                          ),
                          Text(
                            '${activeGoals.length} in progress',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.neutralMuted,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (activeGoals.isEmpty)
                        _buildEmptyCard(
                          icon: Icons.track_changes_rounded,
                          title: 'No active goals right now',
                          subtitle: 'Tap "+ New Goal" below to set your next wellbeing challenge!',
                        )
                      else
                        ...activeGoals.map((goal) => _buildGoalCard(context, ref, goal)),

                      const SizedBox(height: 24),

                      // Daily Activities Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Activities',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.childTextDark,
                            ),
                          ),
                          Text(
                            '${missionsState.completedCount}/${missionsState.missions.length} done',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.childSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (missionsState.missions.isEmpty)
                        _buildEmptyCard(
                          icon: Icons.forest_rounded,
                          title: 'No missions yet',
                          subtitle:
                              'Your parent hasn\'t assigned a new mission. Enjoy your screen-free moments!',
                        )
                      else
                        ...missionsState.missions.map((mission) {
                          final isDone = mission.isCompleted;
                          final isPending = mission.isPendingApproval;
                          final isStarted = mission.isStarted;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(
                                color: isDone
                                    ? AppTheme.childSecondary
                                    : isPending
                                        ? AppTheme.warningOrange
                                        : AppTheme.neutralBorder,
                                width: isDone || isPending ? 1.5 : 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.childPrimary
                                              .withAlpha((0.12 * 255).round()),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${mission.targetMinutes} min',
                                          style: const TextStyle(
                                            color: AppTheme.childPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppTheme.childAccent
                                              .withAlpha((0.2 * 255).round()),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          mission.status.label,
                                          style: const TextStyle(
                                            color: AppTheme.warningOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    mission.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      decoration:
                                          isDone ? TextDecoration.lineThrough : null,
                                      color: AppTheme.childTextDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mission.description,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppTheme.neutralMuted,
                                      height: 1.3,
                                    ),
                                  ),
                                  if (mission.reward != null &&
                                      mission.reward!.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      '🎁 Reward: ${mission.reward}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.warningOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  if (mission.isNeedsRetry &&
                                      mission.parentFeedback != null) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      'Parent feedback: "${mission.parentFeedback}"',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.warningOrange,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Duration: ${mission.targetMinutes} mins',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppTheme.neutralMuted,
                                        ),
                                      ),
                                      if (isDone)
                                        const Text(
                                          'Completed 🎉',
                                          style: TextStyle(
                                            color: AppTheme.successGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        )
                                      else if (isPending)
                                        const Text(
                                          'Waiting for Parent ⏳',
                                          style: TextStyle(
                                            color: AppTheme.warningOrange,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        )
                                      else if (isStarted)
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.childSecondary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                          ),
                                          onPressed: () {
                                            ChildTaskSubmissionDialog.show(
                                              context,
                                              mission: mission,
                                            );
                                          },
                                          child: const Text('Complete & Submit',
                                              style: TextStyle(fontSize: 12)),
                                        )
                                      else
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                AppTheme.childPrimary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                          ),
                                          onPressed: () {
                                            ref
                                                .read(
                                                    childMissionsControllerProvider
                                                        .notifier)
                                                .startTask(mission.id);
                                          },
                                          child: Text(
                                            mission.isNeedsRetry
                                                ? 'Try Again'
                                                : 'Start Activity',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),

                      const SizedBox(height: 80), // Padding for FAB
                    ],
                  ),
                ),

                // ─── TAB 2: COMPLETED GOALS HISTORY ───
                RefreshIndicator(
                  onRefresh: () => ref.read(childGoalsControllerProvider.notifier).loadGoals(),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      if (historyGoals.isEmpty)
                        _buildEmptyCard(
                          icon: Icons.emoji_events_outlined,
                          title: 'No completed goals yet',
                          subtitle: 'Complete goals and activities to build your habit history!',
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

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.only(top: 8, bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.neutralBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppTheme.neutralMuted),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.childTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppTheme.neutralMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalCard(BuildContext context, WidgetRef ref, ChildGoal goal) {
    final isDone = goal.isCompleted;
    final isPaused = goal.status == GoalStatus.paused;
    final isAI = goal.isAIGenerated;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDone
              ? AppTheme.childSecondary
              : isAI
                  ? AppTheme.childPrimary.withAlpha((0.3 * 255).round())
                  : AppTheme.neutralBorder,
          width: isDone || isAI ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getGoalTypeLabel(goal.type),
                        style: TextStyle(
                          color: _getGoalColor(goal.type),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (isAI) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.childPrimary.withAlpha((0.15 * 255).round()),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'AI Recommended',
                          style: TextStyle(
                            color: AppTheme.childPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
                          color: AppTheme.neutralMuted,
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
                        color: AppTheme.neutralMuted,
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
                fontWeight: FontWeight.bold,
                fontSize: 15,
                decoration: isDone ? TextDecoration.lineThrough : null,
                color: isPaused ? AppTheme.neutralMuted : AppTheme.childTextDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              goal.description,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.neutralMuted),
            ),

            const SizedBox(height: 12),

            // Progress bar & label
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${goal.currentMinutes}/${goal.targetMinutes} ${goal.type == GoalType.breakGoal ? "breaks" : "min"}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.childTextDark,
                  ),
                ),
                Text(
                  isDone
                      ? 'Completed 🎉'
                      : isPaused
                          ? 'Paused'
                          : '${goal.progressPercentage}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDone
                        ? AppTheme.childSecondary
                        : isPaused
                            ? AppTheme.neutralMuted
                            : _getGoalColor(goal.type),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: goal.progressRatio,
                backgroundColor: AppTheme.neutralBg,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDone
                      ? AppTheme.childSecondary
                      : isPaused
                          ? AppTheme.neutralMuted
                          : _getGoalColor(goal.type),
                ),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteGoal(BuildContext context, WidgetRef ref, String goalId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Goal?'),
        content: const Text('Are you sure you want to remove this goal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Create Wellbeing Goal 🎯'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Goal Title',
                    hintText: 'e.g. Daily Reading Focus',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'What would you like to achieve?',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<GoalType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(labelText: 'Goal Type'),
                  items: GoalType.values.map((t) {
                    return DropdownMenuItem(
                      value: t,
                      child: Text(_getGoalTypeLabel(t)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: selectedType == GoalType.breakGoal
                        ? 'Target Breaks (count)'
                        : 'Target Minutes',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.childSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
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
              child: const Text('Create', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGoalColor(GoalType type) {
    switch (type) {
      case GoalType.dailyFocus:
        return AppTheme.childPrimary;
      case GoalType.weeklyFocus:
        return AppTheme.childSecondary;
      case GoalType.breakGoal:
        return AppTheme.warningOrange;
      case GoalType.digitalBalance:
        return AppTheme.parentAccent;
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
