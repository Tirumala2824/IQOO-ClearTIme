import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/goal_model.dart';
import '../controllers/child_goals_controller.dart';

class ChildGoalsScreen extends ConsumerWidget {
  const ChildGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goalsState = ref.watch(childGoalsControllerProvider);
    final goals = goalsState.goals;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('My Wellbeing Goals 🎯'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.childSecondary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Goal'),
        onPressed: () => _showAddGoalDialog(context, ref),
      ),
      body: goalsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Top Summary Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.neutralBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryStat(
                        'Total Goals',
                        '${goals.length}',
                        AppTheme.childPrimary,
                      ),
                      _buildSummaryStat(
                        'Completed',
                        '${goalsState.completedGoalsCount}',
                        AppTheme.successGreen,
                      ),
                      _buildSummaryStat(
                        'In Progress',
                        '${goals.length - goalsState.completedGoalsCount}',
                        AppTheme.childAccent,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                ...goals.map((goal) {
                  final isDone = goal.isCompleted;
                  final isPaused = goal.status == GoalStatus.paused;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getGoalColor(goal.type)
                                      .withAlpha((0.15 * 255).round()),
                                  borderRadius: BorderRadius.circular(6),
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
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      isPaused
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded,
                                      size: 20,
                                      color: AppTheme.neutralMuted,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(childGoalsControllerProvider
                                              .notifier)
                                          .toggleGoalPause(goal.id);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      size: 20,
                                      color: AppTheme.alertRed,
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(childGoalsControllerProvider
                                              .notifier)
                                          .deleteGoal(goal.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isPaused
                                  ? AppTheme.neutralMuted
                                  : AppTheme.childTextDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            goal.description,
                            style: const TextStyle(
                                color: AppTheme.neutralMuted, fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${goal.currentMinutes} / ${goal.targetMinutes} ${goal.type == GoalType.breakGoal ? "breaks" : "mins"}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.neutralMuted,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isDone
                                    ? 'Completed! 🌟'
                                    : (isPaused
                                        ? 'Paused'
                                        : '${goal.progressPercentage}%'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDone
                                      ? AppTheme.successGreen
                                      : (isPaused
                                          ? AppTheme.neutralMuted
                                          : AppTheme.childSecondary),
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
                                    ? AppTheme.successGreen
                                    : _getGoalColor(goal.type),
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }

  Widget _buildSummaryStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.neutralMuted),
        ),
      ],
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
        builder: (ctx, setModalState) {
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Create New Wellbeing Goal 🎯',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Goal Title',
                      hintText: 'e.g. Science Reading Focus',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. Read 20 minutes before bed',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<GoalType>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(labelText: 'Goal Category'),
                    items: const [
                      DropdownMenuItem(
                          value: GoalType.dailyFocus,
                          child: Text('Daily Focus')),
                      DropdownMenuItem(
                          value: GoalType.weeklyFocus,
                          child: Text('Weekly Focus')),
                      DropdownMenuItem(
                          value: GoalType.breakGoal,
                          child: Text('Mindful Breaks')),
                      DropdownMenuItem(
                          value: GoalType.digitalBalance,
                          child: Text('Digital Balance')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Target (Minutes or Breaks)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.childSecondary,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          if (titleCtrl.text.trim().isNotEmpty) {
                            ref
                                .read(childGoalsControllerProvider.notifier)
                                .createGoal(
                                  title: titleCtrl.text.trim(),
                                  description: descCtrl.text.trim(),
                                  type: selectedType,
                                  targetMinutes:
                                      int.tryParse(targetCtrl.text) ?? 30,
                                );
                            Navigator.of(ctx).pop();
                          }
                        },
                        child: const Text('Create Goal'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
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
        return AppTheme.successGreen;
    }
  }

  String _getGoalTypeLabel(GoalType type) {
    switch (type) {
      case GoalType.dailyFocus:
        return 'Daily Focus';
      case GoalType.weeklyFocus:
        return 'Weekly Target';
      case GoalType.breakGoal:
        return 'Break Goal';
      case GoalType.digitalBalance:
        return 'Digital Balance';
    }
  }
}
