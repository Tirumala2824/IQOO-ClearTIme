import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:intl/intl.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/models/usage_models.dart';
import '../../authentication/controllers/auth_controller.dart';
import '../../family/widgets/family_selector_dropdown.dart';
import '../../shared/widgets/task_proof_review.dart';
import '../../../services/llm/ai_mission_generator_service.dart';
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
  String? _filterChildId;
  String _missionTypeFilter = 'all'; // 'all', 'parent', 'ai'

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
          content: Text('Please add a child first before assigning activities.'),
        ),
      );
      return;
    }

    ParentCreateTaskDialog.show(
      context,
      children: state.children,
      initialChildId: _filterChildId,
    );
  }

  void _openAiTaskGeneratorSheet(BuildContext context, ParentDashboardState state) {
    if (state.children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a child first before generating AI missions.'),
        ),
      );
      return;
    }

    final targetChild = state.children
            .where((c) => c.id == _filterChildId)
            .firstOrNull ??
        state.children.firstOrNull;
    if (targetChild == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AiMissionGeneratorModal(
        child: targetChild,
        usage: state.childUsageSummaries[targetChild.id],
      ),
    );
  }

  void _openEditTaskDialog(
      BuildContext context, ParentDashboardState state, ChildMission task) {
    ParentCreateTaskDialog.show(
      context,
      children: state.children,
      initialChildId: task.assignedToChildId,
      existingTask: task,
    );
  }

  void _showApproveDialog(BuildContext context, ChildMission task) {
    final feedbackController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.successGreenLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.successGreen, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Approve Activity',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approve "${task.title}" for ${task.assignedToChildNickname ?? "Child"}?',
              style: const TextStyle(fontSize: 14.5, height: 1.4),
            ),
            if (task.reward != null && task.reward!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningOrangeLight,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.card_giftcard_rounded, color: AppColors.warningOrange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Reward to unlock: ${task.reward}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.warningOrange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Encouraging note (optional)',
                hintText: 'e.g. Great job playing outside today!',
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
              backgroundColor: AppColors.successGreen,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.warningOrangeLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.refresh_rounded, color: AppColors.warningOrange, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Request Retry',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ask ${task.assignedToChildNickname ?? "Child"} to give "${task.title}" another try?',
              style: const TextStyle(fontSize: 14.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Helpful feedback note (optional)',
                hintText: 'e.g. Please spend 15 more minutes reading',
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
              backgroundColor: AppColors.warningOrange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Remove Activity?'),
        content: Text('Remove "${task.title}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
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

    // Filter tasks by selected child if filter is active
    final allActiveTasks = [
      ...parentState.pendingReviewTasks,
      ...parentState.activeParentTasks,
    ];
    final activeTasks = _filterChildId == null
        ? allActiveTasks
        : allActiveTasks.where((t) => t.assignedToChildId == _filterChildId).toList();

    final allCompletedTasks = parentState.completedTasks;
    final completedTasks = _filterChildId == null
        ? allCompletedTasks
        : allCompletedTasks.where((t) => t.assignedToChildId == _filterChildId).toList();

    return Scaffold(
      appBar: AppBar(
        title: const FamilySelectorDropdown(),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.parentPrimary),
            tooltip: '✨ AI Agent Auto-Generate Missions',
            onPressed: () => _openAiTaskGeneratorSheet(context, parentState),
          ),
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
          indicatorColor: AppColors.parentPrimary,
          indicatorWeight: 3,
          labelColor: AppColors.parentPrimary,
          unselectedLabelColor: AppColors.neutralMuted,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Active (${activeTasks.length})'),
                  if (parentState.pendingReviewTasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.warningOrange,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '${parentState.pendingReviewTasks.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
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
      body: Column(
        children: [
          // Child Filter Bar (when there are children)
          if (parentState.children.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      selected: _filterChildId == null,
                      label: Text('All Children (${allActiveTasks.length})'),
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: _filterChildId == null
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _filterChildId == null
                            ? Colors.white
                            : AppColors.parentTextDark,
                      ),
                      backgroundColor: AppColors.neutral100,
                      selectedColor: AppColors.parentPrimary,
                      checkmarkColor: Colors.white,
                      onSelected: (_) => setState(() => _filterChildId = null),
                    ),
                    const SizedBox(width: 8),
                    ...parentState.children.map((child) {
                      final isSel = _filterChildId == child.id;
                      final count = allActiveTasks
                          .where((t) => t.assignedToChildId == child.id)
                          .length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          avatar: Icon(Icons.face_rounded,
                              size: 16,
                              color: isSel
                                  ? Colors.white
                                  : AppColors.parentPrimary),
                          selected: isSel,
                          label: Text('${child.nickname} ($count)'),
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSel ? FontWeight.w700 : FontWeight.w500,
                            color: isSel
                                ? Colors.white
                                : AppColors.parentTextDark,
                          ),
                          backgroundColor: AppColors.neutral100,
                          selectedColor: AppColors.parentPrimary,
                          checkmarkColor: Colors.white,
                          onSelected: (selected) {
                            setState(() {
                              _filterChildId = selected ? child.id : null;
                            });
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.neutralBorder),
          ],

          // Origin Filter Bar: All, Parent-Assigned, AI-Assigned
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.neutralBg,
            child: Row(
              children: [
                _buildOriginFilterChip(
                  label: 'All (${activeTasks.length})',
                  value: 'all',
                  icon: Icons.list_alt_rounded,
                ),
                const SizedBox(width: 6),
                _buildOriginFilterChip(
                  label: '🏡 Parent (${activeTasks.where((t) => t.source != MissionSource.localAi && t.type != MissionType.localAi).length})',
                  value: 'parent',
                  icon: Icons.home_rounded,
                ),
                const SizedBox(width: 6),
                _buildOriginFilterChip(
                  label: '🤖 AI (${activeTasks.where((t) => t.source == MissionSource.localAi || t.type == MissionType.localAi).length})',
                  value: 'ai',
                  icon: Icons.smart_toy_rounded,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.neutralBorder),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Active & Pending Review Tasks
                RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(parentDashboardControllerProvider.notifier)
                        .refreshParentTasks();
                  },
                  child: activeTasks.isEmpty
                      ? AppEmptyState(
                          icon: Icons.nature_people_rounded,
                          title: 'No Active Activities',
                          description:
                              'Assign real-world offline tasks or let on-device AI generate counterbalance missions based on your child\'s screen time.',
                          actionLabel: 'Assign Activity',
                          onAction: () =>
                              _openCreateTaskDialog(context, parentState),
                        )
                      : _buildSectionedTasksList(context, parentState, activeTasks, isHistory: false),
                ),

                // Tab 2: Completed Tasks History
                RefreshIndicator(
                  onRefresh: () async {
                    await ref
                        .read(parentDashboardControllerProvider.notifier)
                        .refreshParentTasks();
                  },
                  child: completedTasks.isEmpty
                      ? const AppEmptyState(
                          icon: Icons.task_alt_rounded,
                          title: 'No Completed Activities Yet',
                          description:
                              'When your children complete and you approve their offline activities, they will appear here.',
                        )
                      : _buildSectionedTasksList(context, parentState, completedTasks, isHistory: true),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.parentPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Assign Activity', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _openCreateTaskDialog(context, parentState),
      ),
    );
  }

  Widget _buildOriginFilterChip({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _missionTypeFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _missionTypeFilter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.parentPrimary : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: isSelected ? AppColors.parentPrimary : AppColors.neutralBorder,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.parentPrimary.withAlpha((0.2 * 255).round()),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? Colors.white : AppColors.parentTextSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppColors.parentTextDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionedTasksList(
    BuildContext context,
    ParentDashboardState parentState,
    List<ChildMission> tasks, {
    required bool isHistory,
  }) {
    final parentMissions = tasks
        .where((t) =>
            t.source != MissionSource.localAi && t.type != MissionType.localAi)
        .toList();
    final aiMissions = tasks
        .where((t) =>
            t.source == MissionSource.localAi || t.type == MissionType.localAi)
        .toList();

    if (_missionTypeFilter == 'parent') {
      if (parentMissions.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No parent-assigned missions found.'),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        itemCount: parentMissions.length,
        itemBuilder: (ctx, i) => _buildTaskCard(ctx, parentState, parentMissions[i], isHistory: isHistory),
      );
    }

    if (_missionTypeFilter == 'ai') {
      if (aiMissions.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('No AI-generated missions found.'),
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        itemCount: aiMissions.length,
        itemBuilder: (ctx, i) => _buildTaskCard(ctx, parentState, aiMissions[i], isHistory: isHistory),
      );
    }

    // Default: 'all' -> Render Distinct Visual Sections
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        if (parentMissions.isNotEmpty) ...[
          _buildMissionSectionHeader(
            title: '🏡 Parent-Assigned Real-World Missions',
            subtitle: 'Offline activities, chores, and study goals assigned by parents',
            count: parentMissions.length,
            color: AppColors.parentPrimary,
            icon: Icons.home_rounded,
          ),
          const SizedBox(height: 10),
          ...parentMissions.map((task) => _buildTaskCard(context, parentState, task, isHistory: isHistory)),
          const SizedBox(height: 16),
        ],
        if (aiMissions.isNotEmpty) ...[
          _buildMissionSectionHeader(
            title: '🤖 AI-Assigned Autonomous Missions',
            subtitle: 'Auto-generated on-device by AI to counterbalance screen time',
            count: aiMissions.length,
            color: const Color(0xFF6366F1), // Indigo accent
            icon: Icons.smart_toy_rounded,
          ),
          const SizedBox(height: 10),
          ...aiMissions.map((task) => _buildTaskCard(context, parentState, task, isHistory: isHistory)),
        ],
      ],
    );
  }

  Widget _buildMissionSectionHeader({
    required String title,
    required String subtitle,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withAlpha((0.25 * 255).round())),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha((0.15 * 255).round()),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.neutralMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(BuildContext context, ParentDashboardState parentState,
      ChildMission task, {required bool isHistory}) {
    final dateFormat = DateFormat('MMM d, h:mm a');
    final isPendingReview = task.status == MissionStatus.submitted;
    final isAi = task.source == MissionSource.localAi || task.type == MissionType.localAi;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 14),
      borderColor: isPendingReview
          ? AppColors.warningOrange
          : isHistory
              ? AppColors.successGreen.withAlpha((0.5 * 255).round())
              : isAi
                  ? const Color(0xFF6366F1).withAlpha((0.5 * 255).round())
                  : AppColors.parentPrimary.withAlpha((0.4 * 255).round()),
      borderWidth: isPendingReview || isAi ? 1.5 : 1.0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Origin Banner Chip
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isAi
                  ? const Color(0xFF6366F1).withAlpha((0.12 * 255).round())
                  : AppColors.parentPrimary.withAlpha((0.1 * 255).round()),
              borderRadius: BorderRadius.circular(AppRadius.xs),
              border: Border.all(
                color: isAi
                    ? const Color(0xFF6366F1).withAlpha((0.3 * 255).round())
                    : AppColors.parentPrimary.withAlpha((0.25 * 255).round()),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAi ? Icons.auto_awesome_rounded : Icons.home_rounded,
                  size: 13,
                  color: isAi ? const Color(0xFF6366F1) : AppColors.parentPrimary,
                ),
                const SizedBox(width: 5),
                Text(
                  isAi
                      ? '🤖 AI-ASSIGNED • USAGESTATS AUTONOMOUS MISSION'
                      : '🏡 PARENT-ASSIGNED • REAL-WORLD MISSION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isAi ? const Color(0xFF6366F1) : AppColors.parentPrimary,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),

          // Top Row: Category & Status Chip + Child Nickname + Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (isAi ? const Color(0xFF6366F1) : AppColors.parentPrimary)
                          .withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      '${task.targetMinutes} min',
                      style: TextStyle(
                        color: isAi ? const Color(0xFF6366F1) : AppColors.parentPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(task.status),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.face_rounded, size: 16, color: AppColors.neutralMuted),
                  const SizedBox(width: 4),
                  Text(
                    task.assignedToChildNickname ?? 'Child',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.parentTextDark,
                    ),
                  ),
                  if (!isHistory) ...[
                    const SizedBox(width: 4),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded,
                          size: 20, color: AppColors.neutralMuted),
                      tooltip: 'Activity Options',
                      onSelected: (val) {
                        if (val == 'edit') {
                          _openEditTaskDialog(context, parentState, task);
                        } else if (val == 'delete') {
                          _confirmDelete(context, task);
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 18, color: AppColors.parentPrimary),
                              SizedBox(width: 8),
                              Text('Edit Activity'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  size: 18, color: AppColors.errorRed),
                              SizedBox(width: 8),
                              Text('Delete Activity',
                                  style: TextStyle(color: AppColors.errorRed)),
                            ],
                          ),
                        ),
                      ],
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
              fontWeight: FontWeight.w800,
              color: AppColors.parentTextDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            task.description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.parentTextSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),

          // Metadata Chips: Duration, Reward, Due Date, Proof Requirement
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetaBadge(
                icon: Icons.timer_outlined,
                label: '${task.targetMinutes} mins',
              ),
              if (task.reward != null && task.reward!.isNotEmpty)
                _buildMetaBadge(
                  icon: Icons.card_giftcard_rounded,
                  label: 'Reward: ${task.reward}',
                  color: AppColors.warningOrange,
                ),
              if (task.dueDate != null)
                _buildMetaBadge(
                  icon: Icons.event_outlined,
                  label: 'Due: ${dateFormat.format(task.dueDate!)}',
                  color: task.isExpired ? AppColors.errorRed : null,
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
              (task.proofMediaPath != null || task.submissionNotes != null)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.neutral100,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isPendingReview
                      ? AppColors.warningOrange.withAlpha((0.4 * 255).round())
                      : AppColors.neutralBorder,
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
                            ? AppColors.warningOrange
                            : AppColors.successGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isPendingReview
                            ? 'Submitted Proof (Awaiting Review)'
                            : 'Submitted Proof',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isPendingReview
                              ? AppColors.warningOrange
                              : AppColors.parentTextDark,
                        ),
                      ),
                      if (task.submittedAt != null) ...[
                        const Spacer(),
                        Text(
                          dateFormat.format(task.submittedAt!),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.neutralMuted,
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
                        color: AppColors.parentTextSecondary,
                      ),
                    ),
                  ],
                  if (task.proofMediaPath != null &&
                      task.proofMediaPath!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    TaskProofReview(
                      mediaPath: task.proofMediaPath,
                      mediaType: task.proofMediaType,
                    ),
                  ],
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
                color: AppColors.warningOrangeLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppColors.warningOrange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Requested retry note: "${task.parentFeedback}"',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.warningOrange,
                        fontWeight: FontWeight.w700,
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
                AppButton(
                  label: 'Needs Retry',
                  icon: Icons.refresh_rounded,
                  variant: AppButtonVariant.outlined,
                  size: AppButtonSize.sm,
                  customColor: AppColors.warningOrange,
                  onPressed: () => _showRetryDialog(context, task),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Approve Activity',
                  icon: Icons.check_rounded,
                  variant: AppButtonVariant.secondary,
                  size: AppButtonSize.sm,
                  customColor: AppColors.successGreen,
                  onPressed: () => _showApproveDialog(context, task),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(MissionStatus status) {
    switch (status) {
      case MissionStatus.assigned:
        return AppStatusBadge.primary(label: 'Assigned', icon: Icons.assignment_outlined);
      case MissionStatus.started:
        return AppStatusBadge(
          label: 'In Progress',
          icon: Icons.play_arrow_rounded,
          type: AppStatusType.info,
        );
      case MissionStatus.submitted:
        return AppStatusBadge.warning(label: 'Pending Review');
      case MissionStatus.approved:
        return AppStatusBadge.success(label: 'Completed');
      case MissionStatus.needsRetry:
        return AppStatusBadge.warning(label: 'Needs Retry', icon: Icons.refresh_rounded);
      case MissionStatus.expired:
        return AppStatusBadge.error(label: 'Expired');
    }
  }

  Widget _buildMetaBadge({
    required IconData icon,
    required String label,
    Color? color,
  }) {
    final c = color ?? AppColors.neutralMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(AppRadius.xs),
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

class _AiMissionGeneratorModal extends ConsumerStatefulWidget {
  final ChildProfile child;
  final UsageSummary? usage;

  const _AiMissionGeneratorModal({
    required this.child,
    this.usage,
  });

  @override
  ConsumerState<_AiMissionGeneratorModal> createState() =>
      __AiMissionGeneratorModalState();
}

class __AiMissionGeneratorModalState
    extends ConsumerState<_AiMissionGeneratorModal> {
  bool _isLoading = true;
  List<GeneratedMissionIdea> _ideas = [];
  String? _assigningTitle;

  @override
  void initState() {
    super.initState();
    _fetchIdeas();
  }

  Future<void> _fetchIdeas() async {
    setState(() => _isLoading = true);
    try {
      final generator = ref.read(aiMissionGeneratorServiceProvider);
      final list = await generator.generateMissionsForParent(
        child: widget.child,
        usage: widget.usage,
        count: 3,
      );
      if (mounted) {
        setState(() {
          _ideas = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _assignIdea(GeneratedMissionIdea idea) async {
    final user = ref.read(authControllerProvider).user;
    if (user == null) return;

    setState(() => _assigningTitle = idea.title);
    final success = await ref
        .read(parentDashboardControllerProvider.notifier)
        .createParentTask(
          parentUserId: user.id,
          childId: widget.child.id,
          childNickname: widget.child.nickname,
          title: idea.title,
          description: idea.description,
          durationMinutes: idea.targetMinutes,
          proofRequirement: ProofRequirement.noProof,
          reward: idea.suggestedReward,
        );

    if (mounted) {
      setState(() => _assigningTitle = null);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Assigned "${idea.title}" to ${widget.child.nickname}!'),
                ),
              ],
            ),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.neutralBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.parentSecondary.withAlpha((0.15 * 255).round()),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded,
                    color: AppColors.parentPrimary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Agent Mission Generator',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.parentTextDark,
                      ),
                    ),
                    Text(
                      'Tailored for ${widget.child.nickname}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.neutralMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: AppColors.parentPrimary),
                tooltip: 'Regenerate',
                onPressed: _isLoading ? null : _fetchIdeas,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'AI Agent analyzing habits and generating creative missions...',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.neutralMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Expanded(
              child: ListView.separated(
                itemCount: _ideas.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final idea = _ideas[index];
                  final isAssigning = _assigningTitle == idea.title;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.neutralBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.neutralBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.parentPrimary
                                    .withAlpha((0.12 * 255).round()),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(
                                idea.category.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.parentPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 14, color: AppColors.neutralMuted),
                                const SizedBox(width: 4),
                                Text(
                                  '${idea.targetMinutes} min',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.neutralMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          idea.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.parentTextDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          idea.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.parentTextDark,
                            height: 1.35,
                          ),
                        ),
                        if (idea.suggestedReward != null &&
                            idea.suggestedReward!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.card_giftcard_rounded,
                                  size: 15, color: AppColors.warningOrange),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Reward: ${idea.suggestedReward}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.warningOrange,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.parentPrimary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                            ),
                            icon: isAssigning
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded, size: 16),
                            label: Text(
                              isAssigning
                                  ? 'Assigning...'
                                  : 'Assign to ${widget.child.nickname}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            onPressed: isAssigning
                                ? null
                                : () => _assignIdea(idea),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
