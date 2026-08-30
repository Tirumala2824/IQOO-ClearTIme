import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/mission_model.dart';
import '../../shared/widgets/task_proof_review.dart';
import '../controllers/parent_dashboard_controller.dart';
import 'parent_create_task_dialog.dart';

class ParentTasksScreen extends ConsumerStatefulWidget {
  const ParentTasksScreen({super.key});

  @override
  ConsumerState<ParentTasksScreen> createState() => _ParentTasksScreenState();
}

class _ParentTasksScreenState extends ConsumerState<ParentTasksScreen>
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

  void _openCreateTaskDialog(BuildContext context, ParentDashboardState state) {
    if (state.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a child first before assigning missions.'),
        ),
      );
      return;
    }

    ParentCreateTaskDialog.show(
      context,
      children: state.children,
    );
  }

  void _showApproveDialog(BuildContext context, ChildMission task) {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: AppTheme.successGreen, size: 24),
            const SizedBox(width: 8),
            const Text('Approve Mission 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve "${task.title}" for ${task.assignedToChildNickname ?? "Child"}?'),
            if (task.reward != null) ...[
              const SizedBox(height: 8),
              Text(
                'Reward to fulfill: ${task.reward}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.warningOrange,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Encouraging note (optional)',
                hintText: 'e.g. Great job playing outside!',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref
                  .read(parentDashboardControllerProvider.notifier)
                  .approveTask(task.id, feedback: feedbackController.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRetryDialog(BuildContext context, ChildMission task) {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.refresh_rounded,
                color: AppTheme.warningOrange, size: 24),
            const SizedBox(width: 8),
            const Text('Request Retry 💪'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ask ${task.assignedToChildNickname ?? "Child"} to give "${task.title}" another try?'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'e.g. Please spend 15 more minutes or add a clearer photo',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // A reason is optional per the retry flow; only a
              // parent-provided reason is stored and shown to the child.
              final text = feedbackController.text.trim();
              ref
                  .read(parentDashboardControllerProvider.notifier)
                  .requestTaskRetry(task.id, feedback: text.isEmpty ? null : text);
              Navigator.pop(ctx);
            },
            child: const Text('Request Retry'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, ChildMission task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Mission?'),
        content: Text('Remove "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.alertRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              ref
                  .read(parentDashboardControllerProvider.notifier)
                  .deleteParentTask(task.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parentState = ref.watch(parentDashboardControllerProvider);
    final activeTasks = [
      ...parentState.pendingReviewTasks,
      ...parentState.activeParentTasks,
    ];
    final completedTasks = parentState.completedTasks;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-World Missions 🎯'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: () {
              ref
                  .read(parentDashboardControllerProvider.notifier)
                  .refreshParentTasks();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.parentPrimary,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Active (${activeTasks.length})'),
                  if (parentState.pendingReviewTasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.warningOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${parentState.pendingReviewTasks.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(text: 'Completed (${completedTasks.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Active & Pending Review Tasks
          activeTasks.isEmpty
              ? _buildEmptyState(
                  context,
                  title: 'No Active Missions',
                  subtitle:
                      'Assign real-world offline tasks like reading, outdoor play, helping out, or exercise to help your child disconnect from screens.',
                  showButton: true,
                  onAction: () => _openCreateTaskDialog(context, parentState),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activeTasks.length,
                  itemBuilder: (context, index) {
                    final task = activeTasks[index];
                    return _buildTaskCard(context, task, isHistory: false);
                  },
                ),

          // Tab 2: Completed Tasks History
          completedTasks.isEmpty
              ? _buildEmptyState(
                  context,
                  title: 'No Completed Missions Yet',
                  subtitle:
                      'When your children complete and you approve their offline activities, they will appear here.',
                  showButton: false,
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: completedTasks.length,
                  itemBuilder: (context, index) {
                    final task = completedTasks[index];
                    return _buildTaskCard(context, task, isHistory: true);
                  },
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.parentPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Assign Mission',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openCreateTaskDialog(context, parentState),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool showButton,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.parentPrimary.withAlpha((0.1 * 255).round()),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.forest_rounded,
                size: 40,
                color: AppTheme.parentPrimary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neutralMuted,
                  ),
            ),
            if (showButton) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.parentPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
                onPressed: onAction,
                icon: const Icon(Icons.add_task_rounded),
                label: const Text('Assign Offline Mission'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, ChildMission task,
      {required bool isHistory}) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isPendingReview = task.status == MissionStatus.submitted;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isPendingReview
              ? AppTheme.warningOrange
              : isHistory
                  ? AppTheme.successGreen.withAlpha((0.5 * 255).round())
                  : AppTheme.neutralBorder,
          width: isPendingReview ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category & Status Chip + Child Nickname
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.parentPrimary
                            .withAlpha((0.12 * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${task.targetMinutes} min',
                        style: const TextStyle(
                          color: AppTheme.parentPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildStatusChip(task.status),
                  ],
                ),
                Row(
                  children: [
                    const Icon(Icons.face_rounded,
                        size: 16, color: AppTheme.neutralMuted),
                    const SizedBox(width: 4),
                    Text(
                      task.assignedToChildNickname ?? 'Child',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.parentTextDark,
                      ),
                    ),
                    if (!isHistory) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppTheme.neutralMuted),
                        tooltip: 'Delete Mission',
                        onPressed: () => _confirmDelete(context, task),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Description
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.parentTextDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.neutralMuted,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Metadata: Duration, Reward, Due Date, Proof Requirement
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildMetaBadge(
                  icon: Icons.timer_outlined,
                  label: '${task.targetMinutes} min',
                ),
                if (task.reward != null && task.reward!.isNotEmpty)
                  _buildMetaBadge(
                    icon: Icons.card_giftcard_rounded,
                    label: 'Reward: ${task.reward}',
                    color: AppTheme.warningOrange,
                  ),
                if (task.dueDate != null)
                  _buildMetaBadge(
                    icon: Icons.event_outlined,
                    label: 'Due: ${dateFormat.format(task.dueDate!)}',
                    color: task.isExpired ? AppTheme.alertRed : null,
                  ),
                if (task.proofRequirement != ProofRequirement.noProof)
                  _buildMetaBadge(
                    icon: Icons.verified_outlined,
                    label: task.proofRequirement.label,
                  ),
              ],
            ),

            // Submitted Proof Section (if child has submitted)
            if (task.status == MissionStatus.submitted ||
                (task.proofMediaPath != null ||
                    task.submissionNotes != null)) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.neutralBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isPendingReview
                        ? AppTheme.warningOrange.withAlpha((0.4 * 255).round())
                        : AppTheme.neutralBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPendingReview
                              ? Icons.pending_actions_rounded
                              : Icons.check_circle_outline_rounded,
                          size: 16,
                          color: isPendingReview
                              ? AppTheme.warningOrange
                              : AppTheme.successGreen,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPendingReview
                              ? 'Submitted Proof (Awaiting Approval)'
                              : 'Submitted Proof',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isPendingReview
                                ? AppTheme.warningOrange
                                : AppTheme.parentTextDark,
                          ),
                        ),
                        if (task.submittedAt != null) ...[
                          const Spacer(),
                          Text(
                            dateFormat.format(task.submittedAt!),
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.neutralMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (task.submissionNotes != null &&
                        task.submissionNotes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Notes: "${task.submissionNotes}"',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    // Real proof preview — or a truthful "No proof
                    // submitted" state when the child submitted none.
                    const SizedBox(height: 8),
                    TaskProofReview(
                      mediaPath: task.proofMediaPath,
                      mediaType: task.proofMediaType,
                    ),
                  ],
                ),
              ),
            ],

            // Feedback note if in needsRetry state
            if (task.status == MissionStatus.needsRetry &&
                task.parentFeedback != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      AppTheme.warningOrange.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppTheme.warningOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Requested retry: "${task.parentFeedback}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.warningOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Action Buttons for Parent Review (Approve / Needs Retry)
            if (isPendingReview) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.warningOrange,
                      side: const BorderSide(color: AppTheme.warningOrange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showRetryDialog(context, task),
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Needs Retry'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showApproveDialog(context, task),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Approve Mission'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(MissionStatus status) {
    Color bg;
    Color fg;
    String label = status.label;

    switch (status) {
      case MissionStatus.assigned:
        bg = AppTheme.parentPrimary.withAlpha((0.15 * 255).round());
        fg = AppTheme.parentPrimary;
        break;
      case MissionStatus.started:
        bg = AppTheme.childSecondary.withAlpha((0.15 * 255).round());
        fg = AppTheme.childSecondary;
        break;
      case MissionStatus.submitted:
        bg = AppTheme.warningOrange.withAlpha((0.2 * 255).round());
        fg = AppTheme.warningOrange;
        label = 'Pending Review';
        break;
      case MissionStatus.approved:
        bg = AppTheme.successGreen.withAlpha((0.15 * 255).round());
        fg = AppTheme.successGreen;
        break;
      case MissionStatus.needsRetry:
        bg = AppTheme.warningOrange.withAlpha((0.15 * 255).round());
        fg = AppTheme.warningOrange;
        break;
      case MissionStatus.expired:
        bg = AppTheme.alertRed.withAlpha((0.15 * 255).round());
        fg = AppTheme.alertRed;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetaBadge({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final c = color ?? AppTheme.neutralMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
