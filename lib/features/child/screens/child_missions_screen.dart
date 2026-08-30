import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/reward_model.dart';
import '../controllers/child_dashboard_controller.dart';
import '../controllers/child_missions_controller.dart';
import 'child_task_submission_dialog.dart';

class ChildMissionsScreen extends ConsumerWidget {
  const ChildMissionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionsState = ref.watch(childMissionsControllerProvider);
    final missions = missionsState.missions;

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        title: const Text('My Activities'),
        actions: [
          IconButton(
            tooltip: 'Suggest an AI activity from today\'s usage',
            icon: const Icon(Icons.auto_awesome_rounded),
            onPressed: () async {
              final message = await ref
                  .read(childDashboardControllerProvider.notifier)
                  .generateAiActivity();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
                await ref
                    .read(childMissionsControllerProvider.notifier)
                    .loadMissions();
              }
            },
          ),
        ],
      ),
      body: missionsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : missions.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.childPrimary
                                .withAlpha((0.1 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.forest_rounded,
                            size: 44,
                            color: AppTheme.childPrimary,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'No activities yet',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your parent hasn\'t assigned an activity yet. Go play outside, read a book, or spend time with family!',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.neutralMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  // Real rewards from persisted state are appended after the
                  // missions; nothing is fabricated when no reward exists.
                  itemCount: missions.length +
                      (missionsState.rewards.isEmpty ? 0 : 1),
                  itemBuilder: (context, index) {
                    if (index >= missions.length) {
                      return _buildRewardsSection(context, ref, missionsState.rewards);
                    }
                    final mission = missions[index];
                    final isDone = mission.isCompleted;
                    final isPending = mission.isPendingApproval;
                    final isStarted = mission.isStarted;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.childPrimary
                                        .withAlpha((0.12 * 255).round()),
                                    borderRadius: BorderRadius.circular(8),
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
                                    borderRadius: BorderRadius.circular(10),
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
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                decoration:
                                    isDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              mission.description,
                              style: const TextStyle(
                                color: AppTheme.neutralMuted,
                                fontSize: 13,
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
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                      backgroundColor: AppTheme.childSecondary,
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
                                      backgroundColor: AppTheme.childPrimary,
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
                                          .read(childMissionsControllerProvider
                                              .notifier)
                                          .startTask(mission.id);
                                    },
                                    child: Text(
                                      mission.isNeedsRetry
                                          ? 'Try Again'
                                          : 'Start Mission',
                                      style: const TextStyle(fontSize: 12),
                                    ),
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

  /// Renders the child's real rewards from persisted state. Status chips
  /// reflect the actual reward lifecycle; redemption only happens through
  /// an explicit child action. Nothing is shown when no reward exists.
  Widget _buildRewardsSection(
    BuildContext context,
    WidgetRef ref,
    List<Reward> rewards,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'My Rewards 🎁',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        ...rewards.map((reward) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
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
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            _rewardStatusLabel(reward.status),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _rewardColor(reward.status),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (reward.status == RewardStatus.unlocked)
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.childSecondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                        ),
                        onPressed: () {
                          // Real redemption action by the child/family.
                          ref
                              .read(childMissionsControllerProvider.notifier)
                              .redeemReward(reward.id);
                        },
                        child: const Text('Enjoy it together! 🎉',
                            style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Color _rewardColor(RewardStatus status) {
    switch (status) {
      case RewardStatus.locked:
        return AppTheme.neutralMuted;
      case RewardStatus.unlocked:
        return AppTheme.childSecondary;
      case RewardStatus.redeemed:
        return AppTheme.successGreen;
      case RewardStatus.cancelled:
        return AppTheme.alertRed;
    }
  }

  String _rewardStatusLabel(RewardStatus status) {
    switch (status) {
      case RewardStatus.locked:
        return 'Locked — finish your mission to unlock';
      case RewardStatus.unlocked:
        return 'Unlocked! Enjoy it together.';
      case RewardStatus.redeemed:
        return 'Redeemed — hope you enjoyed it!';
      case RewardStatus.cancelled:
        return 'Cancelled';
    }
  }
}
