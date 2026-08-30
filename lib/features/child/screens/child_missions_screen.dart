import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../../../data/models/mission_model.dart';
import '../../../data/models/reward_model.dart';
import '../../shared/widgets/task_proof_review.dart';
import '../controllers/child_dashboard_controller.dart';
import '../controllers/child_missions_controller.dart';
import 'child_task_submission_dialog.dart';

class ChildMissionsScreen extends ConsumerStatefulWidget {
  const ChildMissionsScreen({super.key});

  @override
  ConsumerState<ChildMissionsScreen> createState() => _ChildMissionsScreenState();
}

class _ChildMissionsScreenState extends ConsumerState<ChildMissionsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childProfile = ref.read(childDashboardControllerProvider).profile;
      ref
          .read(childMissionsControllerProvider.notifier)
          .loadMissions(childId: childProfile?.id);
    });
  }

  Future<void> _generateAiMission(BuildContext context) async {
    final childProfile = ref.read(childDashboardControllerProvider).profile;
    final usage = ref.read(childDashboardControllerProvider).usageSummary;
    final nickname = childProfile?.nickname ?? 'there';

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text('AI Agent is creating your personalized offline mission...'),
          ],
        ),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final generator = ref.read(aiMissionGeneratorServiceProvider);
      final idea = await generator.generateMissionForChild(
        childNickname: nickname,
        usage: usage,
      );

      final missionRepo = ref.read(localMissionRepositoryProvider);
      await missionRepo.createLocalAiMission(
        title: idea.title,
        description: idea.description,
        targetMinutes: idea.targetMinutes,
      );

      final updatedMissions =
          await missionRepo.getMissions(childId: childProfile?.id);
      ref
          .read(childDashboardControllerProvider.notifier)
          .updateMissionsLocally(updatedMissions);
      await ref
          .read(childMissionsControllerProvider.notifier)
          .loadMissions(childId: childProfile?.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.stars_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('New Mission Added: "${idea.title}" (${idea.targetMinutes}m)! 🚀'),
                ),
              ],
            ),
            backgroundColor: AppColors.childSecondary,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not generate mission: $e'),
            backgroundColor: AppColors.alertRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final missionsState = ref.watch(childMissionsControllerProvider);
    final missions = missionsState.missions;

    return Scaffold(
      backgroundColor: AppColors.childSurface,
      appBar: AppBar(
        backgroundColor: AppColors.childSurface,
        title: const Text('My Real-World Activities'),
        actions: [
          IconButton(
            tooltip: '✨ AI Agent Auto-Generate Mission',
            icon: const Icon(Icons.auto_awesome_rounded, color: AppColors.childPrimary),
            onPressed: () => _generateAiMission(context),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              final childProfile =
                  ref.read(childDashboardControllerProvider).profile;
              await ref
                  .read(childMissionsControllerProvider.notifier)
                  .loadMissions(childId: childProfile?.id);
            },
          ),
        ],
      ),
      body: missionsState.isLoading
          ? const AppLoadingState(message: 'Loading your activities...')
          : RefreshIndicator(
              onRefresh: () async {
                final childProfile =
                    ref.read(childDashboardControllerProvider).profile;
                await ref
                    .read(childMissionsControllerProvider.notifier)
                    .loadMissions(childId: childProfile?.id);
              },
              child: missions.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 40),
                        child: Column(
                          children: [
                            AppEmptyState(
                              icon: Icons.park_rounded,
                              title: 'No Activities Yet',
                              description:
                                  'Ready to build great habits? You can ask the AI Agent to generate a fun, creative mission right now!',
                              iconColor: AppColors.childSecondary,
                              actionLabel: '✨ AI Agent Generate Mission',
                              onAction: () => _generateAiMission(context),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18.0, vertical: 12.0),
                      itemCount: missions.length +
                          (missionsState.rewards.isEmpty ? 0 : 1),
                      itemBuilder: (context, index) {
                        if (index >= missions.length) {
                          return _buildRewardsSection(
                              context, ref, missionsState.rewards);
                        }
                        final mission = missions[index];
                        final isDone = mission.isCompleted;
                        final isPending = mission.isPendingApproval;
                        final isStarted = mission.isStarted;

                        return AppCard(
                          margin: const EdgeInsets.only(bottom: 14),
                          borderColor: isDone
                              ? AppColors.childSecondary
                              : isPending
                                  ? AppColors.warningOrange
                                  : isStarted
                                      ? AppColors.childPrimary
                                      : AppColors.neutralBorder,
                          borderWidth:
                              isDone || isPending || isStarted ? 1.5 : 1.0,
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
                                      color: AppColors.childPrimary.withAlpha(
                                          (0.12 * 255).round()),
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.xs),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.timer_outlined,
                                            size: 13,
                                            color: AppColors.childPrimary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${mission.targetMinutes} min',
                                          style: const TextStyle(
                                            color: AppColors.childPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildChildMissionStatusBadge(mission),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                mission.title,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.childTextDark,
                                  decoration:
                                      isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                mission.description,
                                style: const TextStyle(
                                  color: AppColors.childTextSecondary,
                                  fontSize: 13.5,
                                  height: 1.35,
                                ),
                              ),
                              if (mission.reward != null &&
                                  mission.reward!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningOrangeLight,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.card_giftcard_rounded,
                                          size: 16,
                                          color: AppColors.warningOrange),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Reward: ${mission.reward}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.warningOrange,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (mission.isNeedsRetry &&
                                  mission.parentFeedback != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningOrangeLight,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          size: 16,
                                          color: AppColors.warningOrange),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Parent feedback: "${mission.parentFeedback}"',
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

                              // Attached Submitted Proof Preview (for submitted/completed missions)
                              if (mission.proofMediaPath != null &&
                                  mission.proofMediaPath!.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppColors.neutral100,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                        color: AppColors.neutralBorder),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            isDone
                                                ? Icons.check_circle_outline
                                                : Icons.attachment_rounded,
                                            size: 15,
                                            color: isDone
                                                ? AppColors.successGreen
                                                : AppColors.childPrimary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            isDone
                                                ? 'Approved Proof Media'
                                                : 'Your Attached Proof Media',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: isDone
                                                  ? AppColors.successGreen
                                                  : AppColors.childPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      TaskProofReview(
                                        mediaPath: mission.proofMediaPath,
                                        mediaType: mission.proofMediaType,
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Target: ${mission.targetMinutes} mins',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.neutralMuted,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isDone)
                                    const AppStatusBadge(
                                      label: 'Completed 🎉',
                                      type: AppStatusType.success,
                                    )
                                  else if (isPending)
                                    const AppStatusBadge(
                                      label: 'Waiting for Parent Review ⏳',
                                      type: AppStatusType.warning,
                                    )
                                  else if (isStarted)
                                    AppButton(
                                      label: 'Complete & Submit',
                                      icon: Icons.check_circle_outline_rounded,
                                      variant: AppButtonVariant.secondary,
                                      size: AppButtonSize.sm,
                                      onPressed: () {
                                        ChildTaskSubmissionDialog.show(
                                          context,
                                          mission: mission,
                                        );
                                      },
                                    )
                                  else
                                    AppButton(
                                      label: mission.isNeedsRetry
                                          ? 'Try Again'
                                          : 'Start Activity',
                                      icon: Icons.play_arrow_rounded,
                                      variant: AppButtonVariant.primary,
                                      size: AppButtonSize.sm,
                                      onPressed: () {
                                        ref
                                            .read(
                                                childMissionsControllerProvider
                                                    .notifier)
                                            .startTask(mission.id);
                                      },
                                    ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildChildMissionStatusBadge(ChildMission mission) {
    if (mission.isCompleted) {
      return AppStatusBadge.success(label: 'Done');
    }
    if (mission.isPendingApproval) {
      return AppStatusBadge.warning(label: 'Pending Review');
    }
    if (mission.isStarted) {
      return const AppStatusBadge(
          label: 'In Progress',
          type: AppStatusType.info,
          icon: Icons.play_circle_outline_rounded);
    }
    if (mission.isNeedsRetry) {
      return AppStatusBadge.warning(
          label: 'Needs Retry', icon: Icons.refresh_rounded);
    }
    return AppStatusBadge.primary(label: 'Assigned');
  }

  Widget _buildRewardsSection(
    BuildContext context,
    WidgetRef ref,
    List<Reward> rewards,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Text(
          'My Unlocked Rewards 🎁',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.childTextDark,
              ),
        ),
        const SizedBox(height: 10),
        ...rewards.map((reward) => AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _rewardColor(reward.status)
                          .withAlpha((0.15 * 255).round()),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      reward.status == RewardStatus.redeemed
                          ? Icons.celebration_rounded
                          : Icons.card_giftcard_rounded,
                      color: _rewardColor(reward.status),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: AppColors.childTextDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _rewardStatusLabel(reward.status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _rewardColor(reward.status),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reward.status == RewardStatus.unlocked)
                    AppButton(
                      label: 'Claim 🎉',
                      size: AppButtonSize.sm,
                      variant: AppButtonVariant.secondary,
                      onPressed: () {
                        ref
                            .read(childMissionsControllerProvider.notifier)
                            .redeemReward(reward.id);
                      },
                    ),
                ],
              ),
            )),
      ],
    );
  }

  Color _rewardColor(RewardStatus status) {
    switch (status) {
      case RewardStatus.locked:
        return AppColors.neutralMuted;
      case RewardStatus.unlocked:
        return AppColors.childSecondary;
      case RewardStatus.redeemed:
        return AppColors.successGreen;
      case RewardStatus.cancelled:
        return AppColors.errorRed;
    }
  }

  String _rewardStatusLabel(RewardStatus status) {
    switch (status) {
      case RewardStatus.locked:
        return 'Locked — complete activity to unlock';
      case RewardStatus.unlocked:
        return 'Unlocked! Ready to enjoy together.';
      case RewardStatus.redeemed:
        return 'Claimed — hope you had fun!';
      case RewardStatus.cancelled:
        return 'Cancelled';
    }
  }
}
