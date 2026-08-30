import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/goal_model.dart';
import '../controllers/child_dashboard_controller.dart';
import '../controllers/child_missions_controller.dart';
import 'child_reflection_dialog.dart';
import 'child_task_submission_dialog.dart';

class ChildDashboardScreen extends ConsumerStatefulWidget {
  const ChildDashboardScreen({super.key});

  @override
  ConsumerState<ChildDashboardScreen> createState() =>
      _ChildDashboardScreenState();
}

class _ChildDashboardScreenState extends ConsumerState<ChildDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final childState = ref.read(childDashboardControllerProvider);
      final userId = childState.profile?.userId ?? '';
      await ref
          .read(childDashboardControllerProvider.notifier)
          .loadDashboard(userId);
      final updatedProfile =
          ref.read(childDashboardControllerProvider).profile;
      await ref
          .read(childMissionsControllerProvider.notifier)
          .loadMissions(childId: updatedProfile?.id);
    });
  }

  String _getEncouragement(int focusMinutes, int breakCount, int totalMinutes) {
    if (totalMinutes == 0) {
      return "Start your day with mindful screen habits! ☀️";
    }
    if (focusMinutes >= 60) {
      return "Fantastic focus today! You're making great progress. 🌟";
    }
    if (focusMinutes >= 30) {
      return "Great learning time! Remember to take regular eye breaks. 👀";
    }
    if (breakCount >= 3) {
      return "Awesome job taking mindful pauses today! 🌿";
    }
    return "Every mindful minute helps you build great digital habits! 🚀";
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(childDashboardControllerProvider);
    final profile = childState.profile;
    final usage = childState.usageSummary;
    final reflection = childState.todayReflection;
    final activeGoal = childState.activeAIGoal ??
        (childState.goals.isNotEmpty
            ? childState.goals.firstWhere(
                (g) => g.status == GoalStatus.active,
                orElse: () => childState.goals.first,
              )
            : null);

    final childName = profile?.nickname ?? "there";

    return Scaffold(
      backgroundColor: AppColors.childSurface,
      appBar: AppBar(
        backgroundColor: AppColors.childSurface,
        title: Text(
          'Hey, $childName! 👋',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppColors.childTextDark,
          ),
        ),
        actions: [
          IconButton(
            icon: childState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, color: AppColors.childPrimary),
            tooltip: 'Refresh',
            onPressed: () {
              ref
                  .read(childDashboardControllerProvider.notifier)
                  .loadDashboard(profile?.userId ?? '');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final userId = profile?.userId ?? '';
          await ref
              .read(childDashboardControllerProvider.notifier)
              .loadDashboard(userId);
          final updatedProfile =
              ref.read(childDashboardControllerProvider).profile;
          await ref
              .read(childMissionsControllerProvider.notifier)
              .loadMissions(childId: updatedProfile?.id);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Permission banner if usage access needed
              if (!childState.hasUsageAccess) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warningOrangeLight,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.warningOrange),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded,
                          color: AppColors.warningOrange, size: 26),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Usage permission is needed to track your daily screen balance.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.parentTextDark,
                          ),
                        ),
                      ),
                      AppButton(
                        label: 'Setup',
                        size: AppButtonSize.sm,
                        customColor: AppColors.warningOrange,
                        onPressed: () async {
                          await context.push(AppRoutes.usageAccessSetup);
                          if (context.mounted) {
                            await ref
                                .read(childDashboardControllerProvider.notifier)
                                .refreshUsageAccess();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // 1. Hero Wellbeing Banner
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.childPrimary, AppColors.childSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.childPrimary.withAlpha((0.25 * 255).round()),
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
                        const Text(
                          'TODAY\'S BALANCE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            '✓ ${childState.completedMissionsCount} activities finished',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _getEncouragement(
                          usage.focusMinutes, usage.breakCount, usage.totalMinutes),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildHeroMetric(
                          label: 'Screen Time',
                          value: usage.totalMinutes > 0
                              ? usage.formattedTotalTime
                              : '0m',
                          icon: Icons.timer_outlined,
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withAlpha((0.3 * 255).round()),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        _buildHeroMetric(
                          label: 'Focus Time',
                          value: usage.focusMinutes > 0
                              ? usage.formattedFocusTime
                              : '0m',
                          icon: Icons.bolt_rounded,
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withAlpha((0.3 * 255).round()),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        _buildHeroMetric(
                          label: 'Breaks',
                          value: '${usage.breakCount}',
                          icon: Icons.self_improvement_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 2. Real-World Offline Mission Quest Card
              Builder(
                builder: (context) {
                  final missionsState = ref.watch(childMissionsControllerProvider);
                  final activeMission = missionsState.activeMissions.isNotEmpty
                      ? missionsState.activeMissions.first
                      : (missionsState.submittedMissions.isNotEmpty
                          ? missionsState.submittedMissions.first
                          : null);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Today\'s Activity Quest',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.childTextDark,
                            ),
                          ),
                          if (missionsState.missions.isNotEmpty)
                            TextButton(
                              onPressed: () => context.go(AppRoutes.childGoals),
                              child: Text('All (${missionsState.missions.length})'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (activeMission != null) ...[
                        AppCard(
                          borderColor: activeMission.isPendingApproval
                              ? AppColors.warningOrange
                              : activeMission.isStarted
                                  ? AppColors.childSecondary
                                  : AppColors.childPrimary,
                          borderWidth: 1.5,
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
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined, size: 13, color: AppColors.childPrimary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${activeMission.targetMinutes} min',
                                          style: const TextStyle(
                                            color: AppColors.childPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (activeMission.isPendingApproval)
                                    AppStatusBadge.warning(label: 'Pending Review')
                                  else if (activeMission.isStarted)
                                    const AppStatusBadge(label: 'In Progress', type: AppStatusType.info)
                                  else
                                    AppStatusBadge.primary(label: 'Ready to Start'),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                activeMission.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.childTextDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeMission.description,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  color: AppColors.childTextSecondary,
                                  height: 1.35,
                                ),
                              ),
                              if (activeMission.reward != null &&
                                  activeMission.reward!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningOrangeLight,
                                    borderRadius: BorderRadius.circular(AppRadius.xs),
                                  ),
                                  child: Text(
                                    '🎁 Reward: ${activeMission.reward}',
                                    style: const TextStyle(
                                      color: AppColors.warningOrange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 14),

                              if (activeMission.isPendingApproval)
                                const AppStatusBadge(
                                  label: 'Submitted — Waiting for parent review ⏳',
                                  type: AppStatusType.warning,
                                )
                              else if (activeMission.isStarted)
                                AppButton(
                                  label: 'Complete & Add Proof',
                                  icon: Icons.check_circle_outline_rounded,
                                  variant: AppButtonVariant.secondary,
                                  isFullWidth: true,
                                  onPressed: () {
                                    ChildTaskSubmissionDialog.show(
                                      context,
                                      mission: activeMission,
                                    );
                                  },
                                )
                              else
                                AppButton(
                                  label: activeMission.isNeedsRetry ? 'Try Again' : 'Start Activity',
                                  icon: Icons.play_arrow_rounded,
                                  variant: AppButtonVariant.primary,
                                  isFullWidth: true,
                                  onPressed: () {
                                    ref
                                        .read(childMissionsControllerProvider.notifier)
                                        .startTask(activeMission.id);
                                  },
                                ),
                            ],
                          ),
                        ),
                      ] else ...[
                        AppEmptyState(
                          icon: Icons.park_outlined,
                          title: 'No active quest right now',
                          description: 'When your parent assigns an activity, it will appear right here!',
                          iconColor: AppColors.childSecondary,
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),

              // 3. Active Goal Progress Card
              if (activeGoal != null) ...[
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Focus Goal',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.childTextDark,
                            ),
                          ),
                          AppStatusBadge.primary(label: '${activeGoal.progressPercentage}%'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        activeGoal.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppProgressBar(
                        progress: activeGoal.progressRatio,
                        label: '${activeGoal.currentMinutes}/${activeGoal.targetMinutes} mins completed',
                        color: AppColors.childSecondary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 4. Daily Mindful Reflection Card
              AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: AppColors.childPrimaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          color: AppColors.childPrimary, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Mindful Reflection',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              color: AppColors.childTextDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reflection != null
                                ? 'Reflection recorded for today! 🌿'
                                : 'How was your balance and focus today?',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.childTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppButton(
                      label: reflection != null ? 'View' : 'Reflect',
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.outlined,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ChildReflectionDialog(
                            existingReflection: reflection,
                            onSave: (result) {
                              ref
                                  .read(childDashboardControllerProvider.notifier)
                                  .saveReflection(
                                    mood: result.mood,
                                    notes: result.notes,
                                  );
                            },
                            onDelete: reflection != null
                                ? () {
                                    ref
                                        .read(childDashboardControllerProvider.notifier)
                                        .deleteTodayReflection();
                                  }
                                : null,
                          ),
                        );
                      },
                    ),
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

  Widget _buildHeroMetric({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
