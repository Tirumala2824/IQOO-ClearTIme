import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/reflection_model.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final childState = ref.read(childDashboardControllerProvider);
      final userId = childState.profile?.userId ?? '';
      ref.read(childDashboardControllerProvider.notifier).loadDashboard(userId);
      ref.read(childMissionsControllerProvider.notifier).loadMissions(childId: userId);
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
    final patterns = childState.detectedPatterns;

    final childName = profile?.nickname ?? "Explorer";

    return Scaffold(
      backgroundColor: AppTheme.childSurface,
      appBar: AppBar(
        backgroundColor: AppTheme.childSurface,
        elevation: 0,
        title: Text(
          'Hey, $childName! 👋',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 22,
            color: AppTheme.childTextDark,
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
                : const Icon(Icons.refresh_rounded, color: AppTheme.childPrimary),
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
          await ref
              .read(childMissionsControllerProvider.notifier)
              .loadMissions(childId: userId);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Permission banner if usage access needed
              if (!childState.hasPermission) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.warningOrange.withAlpha((0.15 * 255).round()),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.warningOrange.withAlpha((0.4 * 255).round()),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.touch_app_rounded,
                          color: AppTheme.warningOrange, size: 28),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Enable Usage Access to track your daily quests on this phone.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.warningOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          ref
                              .read(childDashboardControllerProvider.notifier)
                              .requestUsagePermission();
                        },
                        child: const Text('Enable'),
                      ),
                    ],
                  ),
                ),
              ],

              // ─── 1. HERO WELLBEING BANNER ───
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.childPrimary, AppTheme.childSecondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.childPrimary.withAlpha((0.25 * 255).round()),
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
                          'TODAY\'S WELLBEING',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha((0.2 * 255).round()),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '⭐ ${childState.totalPoints} XP Earned',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
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

              // ─── 2. REAL-WORLD OFFLINE MISSION ───
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
                          Text(
                            'Real-World Mission 🚀',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.childTextDark,
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
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: activeMission.isPendingApproval
                                  ? AppTheme.warningOrange
                                  : activeMission.isStarted
                                      ? AppTheme.childSecondary
                                      : AppTheme.childPrimary.withAlpha((0.4 * 255).round()),
                              width: 1.5,
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
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.childPrimary
                                          .withAlpha((0.12 * 255).round()),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.forest_rounded,
                                            size: 14, color: AppTheme.childPrimary),
                                        const SizedBox(width: 4),
                                        Text(
                                          activeMission.category,
                                          style: const TextStyle(
                                            color: AppTheme.childPrimary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
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
                                      '+${activeMission.points} XP',
                                      style: const TextStyle(
                                        color: AppTheme.warningOrange,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                activeMission.title,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.childTextDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeMission.description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.neutralMuted,
                                  height: 1.3,
                                ),
                              ),
                              if (activeMission.reward != null &&
                                  activeMission.reward!.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningOrange
                                        .withAlpha((0.12 * 255).round()),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.card_giftcard_rounded,
                                          size: 16, color: AppTheme.warningOrange),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Reward: ${activeMission.reward}',
                                        style: const TextStyle(
                                          color: AppTheme.warningOrange,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (activeMission.isNeedsRetry &&
                                  activeMission.parentFeedback != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningOrange
                                        .withAlpha((0.12 * 255).round()),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline,
                                          size: 16, color: AppTheme.warningOrange),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Parent Note: "${activeMission.parentFeedback}"',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.warningOrange,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),

                              // Action button for child
                              if (activeMission.isPendingApproval) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10, horizontal: 14),
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningOrange
                                        .withAlpha((0.12 * 255).round()),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.hourglass_top_rounded,
                                          size: 16, color: AppTheme.warningOrange),
                                      SizedBox(width: 8),
                                      Text(
                                        'Submitted — Waiting for parent review ⏳',
                                        style: TextStyle(
                                          color: AppTheme.warningOrange,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (activeMission.isStarted) ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.childSecondary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      ChildTaskSubmissionDialog.show(
                                        context,
                                        mission: activeMission,
                                      );
                                    },
                                    icon: const Icon(Icons.check_circle_outline_rounded,
                                        size: 18),
                                    label: const Text(
                                      'Complete Activity & Submit',
                                      style: TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ] else ...[
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.childPrimary,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () {
                                      ref
                                          .read(childMissionsControllerProvider.notifier)
                                          .startTask(activeMission.id);
                                    },
                                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                                    label: Text(
                                      activeMission.isNeedsRetry
                                          ? 'Try Again (${activeMission.targetMinutes}m)'
                                          : 'Start Mission (${activeMission.targetMinutes}m)',
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ] else ...[
                        // Authentic empty state when no parent mission assigned
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: AppTheme.neutralBorder),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.childPrimary
                                      .withAlpha((0.08 * 255).round()),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.forest_rounded,
                                  size: 32,
                                  color: AppTheme.childPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'No missions yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppTheme.childTextDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Your parent hasn\'t assigned a new mission. Enjoy your mindful day!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: AppTheme.neutralMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 20),

              // ─── 3. CURRENT ACTIVE GOAL (MAIN ACTION) ───
              Text(
                'Current Goal 🎯',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.childTextDark,
                    ),
              ),
              const SizedBox(height: 8),

              if (activeGoal != null) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: activeGoal.isCompleted
                          ? AppTheme.childSecondary
                          : AppTheme.neutralBorder,
                      width: activeGoal.isCompleted ? 1.5 : 1.0,
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.childPrimary
                                  .withAlpha((0.12 * 255).round()),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flag_rounded,
                                    size: 14, color: AppTheme.childPrimary),
                                const SizedBox(width: 4),
                                Text(
                                  activeGoal.isAIGenerated
                                      ? 'Daily Habit Goal'
                                      : 'Personal Goal',
                                  style: const TextStyle(
                                    color: AppTheme.childPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            activeGoal.isCompleted
                                ? 'Completed! 🎉'
                                : '${activeGoal.currentMinutes}/${activeGoal.targetMinutes} ${activeGoal.type == GoalType.breakGoal ? "breaks" : "min"}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: activeGoal.isCompleted
                                  ? AppTheme.childSecondary
                                  : AppTheme.neutralMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        activeGoal.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.childTextDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeGoal.description,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.neutralMuted,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: activeGoal.progressRatio,
                          backgroundColor: AppTheme.neutralBg,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            activeGoal.isCompleted
                                ? AppTheme.childSecondary
                                : AppTheme.childPrimary,
                          ),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => context.go(AppRoutes.childGoals),
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: const Text('View All Goals & Quests'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Meaningful empty goal card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.neutralBorder),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.track_changes_rounded,
                          size: 36, color: AppTheme.childPrimary),
                      const SizedBox(height: 8),
                      const Text(
                        'No active goal set yet',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Start a focus goal or tap below to let your AI coach suggest one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.neutralMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                        label: const Text('Set My First Goal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.childPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => context.go(AppRoutes.childGoals),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // ─── 3. FRIENDLY AI COACHING BUDDY CARD ───
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: AppTheme.childSecondary.withAlpha((0.3 * 255).round()),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.childSecondary.withAlpha((0.06 * 255).round()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.childSecondary
                                .withAlpha((0.15 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: const Text('🌱', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'AI Coaching Buddy',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.childTextDark,
                            ),
                          ),
                        ),
                        if (childState.isCoachingLoopRunning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (patterns.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.childSurface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(patterns.first.emoji,
                                style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    patterns.first.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    patterns.first.suggestedAction,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.neutralMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        usage.totalMinutes == 0
                            ? "We're still collecting today's activity. Keep using your phone mindfully!"
                            : "Balanced habits observed today! Take a quick stretch break whenever you finish a task.",
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.neutralMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── 4. DAILY MINDFUL CHECK-IN / REFLECTION ───
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppTheme.neutralBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.childAccent.withAlpha((0.15 * 255).round()),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        reflection?.mood.emoji ?? '✨',
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            reflection != null
                                ? 'Today felt ${reflection.mood.label}!'
                                : 'How did your screen time feel?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            reflection?.notes ??
                                'Tap to record how your day felt.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.neutralMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.childSecondary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ChildReflectionDialog(
                            existingReflection: reflection,
                            onSave: (data) {
                              ref
                                  .read(
                                      childDashboardControllerProvider.notifier)
                                  .saveReflection(
                                    mood: data.mood,
                                    notes: data.notes,
                                  );
                            },
                            onDelete: () {
                              ref
                                  .read(
                                      childDashboardControllerProvider.notifier)
                                  .deleteTodayReflection();
                            },
                          ),
                        );
                      },
                      child: Text(reflection != null ? 'Edit' : 'Reflect'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ─── 5. PRIVACY & SAFETY ASSURANCE ───
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.childSecondary.withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        color: AppTheme.childSecondary, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '100% On-Device: Your usage notes and reflections stay private on this phone.',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.childSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white70, size: 13),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
