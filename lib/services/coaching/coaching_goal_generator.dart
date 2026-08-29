import '../../data/models/coaching_models.dart';
import '../../data/models/goal_model.dart';
import 'package:uuid/uuid.dart';

/// Deterministic goal generator that creates personalized, age-appropriate goals.
///
/// Works 100% offline. Generates one goal based on detected patterns and
/// adjusts difficulty based on previous evaluation history.
class CoachingGoalGenerator {
  const CoachingGoalGenerator();

  /// Generates a personalized goal based on detected patterns and history.
  ChildGoal generateGoal({
    required List<DetectedPattern> patterns,
    List<GoalEvaluation> previousEvaluations = const [],
    List<ChildGoal> previousGoals = const [],
  }) {
    const uuid = Uuid();
    final now = DateTime.now();

    // Determine difficulty adjustment based on recent evaluations
    final difficultyMultiplier = _calculateDifficultyMultiplier(previousEvaluations);

    // Find the most actionable pattern to base the goal on
    final targetPattern = _selectTargetPattern(patterns, previousGoals);

    // Generate goal based on the selected pattern
    final goal = _createGoalFromPattern(
      pattern: targetPattern,
      difficultyMultiplier: difficultyMultiplier,
      goalId: 'ai-${uuid.v4().substring(0, 8)}',
      createdAt: now,
    );

    return goal;
  }

  /// Calculates how much to adjust goal difficulty.
  /// > 1.0 means harder (child has been doing well)
  /// < 1.0 means easier (child has been struggling)
  /// = 1.0 means baseline
  double _calculateDifficultyMultiplier(List<GoalEvaluation> evaluations) {
    if (evaluations.isEmpty) return 1.0;

    // Look at last 3 evaluations
    final recent = evaluations.length > 3
        ? evaluations.sublist(evaluations.length - 3)
        : evaluations;

    final avgScore = recent.fold<int>(0, (s, e) => s + e.score) / recent.length;

    if (avgScore >= 80) return 1.2; // Child is excelling → slightly harder
    if (avgScore >= 60) return 1.0; // Doing well → maintain
    if (avgScore >= 40) return 0.85; // Struggling → slightly easier
    return 0.7; // Really struggling → much easier
  }

  /// Selects the most actionable pattern, avoiding repeating the same goal type.
  DetectedPattern _selectTargetPattern(
    List<DetectedPattern> patterns,
    List<ChildGoal> previousGoals,
  ) {
    // Prioritize concerning patterns first (they need attention)
    final concerning =
        patterns.where((p) => p.type == PatternType.concerning).toList();
    if (concerning.isNotEmpty) {
      // Avoid repeating same category as the last AI goal
      final lastAIGoal = previousGoals
          .where((g) => g.source == GoalSource.aiGenerated)
          .toList();
      if (lastAIGoal.isNotEmpty) {
        final lastType = lastAIGoal.last.type;
        final different =
            concerning.where((p) => _patternToGoalType(p) != lastType).toList();
        if (different.isNotEmpty) return different.first;
      }
      return concerning.first;
    }

    // Then positive patterns (to reinforce good behavior)
    final positive =
        patterns.where((p) => p.type == PatternType.positive).toList();
    if (positive.isNotEmpty) return positive.first;

    // Fallback to first pattern
    return patterns.first;
  }

  GoalType _patternToGoalType(DetectedPattern pattern) {
    switch (pattern.category) {
      case PatternCategory.focusTime:
      case PatternCategory.learningStreak:
        return GoalType.dailyFocus;
      case PatternCategory.breakHabits:
        return GoalType.breakGoal;
      case PatternCategory.gaming:
      case PatternCategory.balanceShift:
        return GoalType.digitalBalance;
      case PatternCategory.screenTotal:
      case PatternCategory.improvement:
      case PatternCategory.lateNight:
        return GoalType.dailyFocus;
    }
  }

  /// Creates a concrete goal from a detected pattern.
  ChildGoal _createGoalFromPattern({
    required DetectedPattern pattern,
    required double difficultyMultiplier,
    required String goalId,
    required DateTime createdAt,
  }) {
    switch (pattern.category) {
      case PatternCategory.focusTime:
        if (pattern.type == PatternType.concerning) {
          final target = (30 * difficultyMultiplier).round().clamp(15, 90);
          return ChildGoal(
            id: goalId,
            title: 'Focus Power-Up Challenge',
            description:
                'Reach $target minutes of focused learning today. '
                'Pick your favorite educational app and dive in!',
            type: GoalType.dailyFocus,
            targetMinutes: target,
            source: GoalSource.aiGenerated,
            relatedPattern: pattern.title,
            createdAt: createdAt,
          );
        } else {
          final target = (75 * difficultyMultiplier).round().clamp(45, 120);
          return ChildGoal(
            id: goalId,
            title: 'Focus Champion Mode',
            description:
                'You\'re doing great! Push for $target minutes of focused time today. You\'ve got this!',
            type: GoalType.dailyFocus,
            targetMinutes: target,
            source: GoalSource.aiGenerated,
            relatedPattern: pattern.title,
            createdAt: createdAt,
          );
        }

      case PatternCategory.breakHabits:
        if (pattern.type == PatternType.concerning) {
          final target = (3 * difficultyMultiplier).round().clamp(2, 6);
          return ChildGoal(
            id: goalId,
            title: 'Mindful Pause Quest',
            description:
                'Take $target screen breaks today. After every 20 minutes, '
                'look away for 20 seconds. Your eyes will thank you!',
            type: GoalType.breakGoal,
            targetMinutes: target, // using targetMinutes as count for breaks
            source: GoalSource.aiGenerated,
            relatedPattern: pattern.title,
            createdAt: createdAt,
          );
        } else {
          final target = (5 * difficultyMultiplier).round().clamp(4, 8);
          return ChildGoal(
            id: goalId,
            title: 'Break Master Streak',
            description:
                'Keep your awesome break habit going! Aim for $target healthy '
                'pauses today.',
            type: GoalType.breakGoal,
            targetMinutes: target,
            source: GoalSource.aiGenerated,
            relatedPattern: pattern.title,
            createdAt: createdAt,
          );
        }

      case PatternCategory.gaming:
      case PatternCategory.balanceShift:
        final target = (45 * difficultyMultiplier).round().clamp(20, 60);
        return ChildGoal(
          id: goalId,
          title: 'Balance Explorer Challenge',
          description:
              'Keep recreational time under $target minutes today and try '
              'swapping some play time for creative or learning activities.',
          type: GoalType.digitalBalance,
          targetMinutes: target,
          source: GoalSource.aiGenerated,
          relatedPattern: pattern.title,
          createdAt: createdAt,
        );

      case PatternCategory.screenTotal:
        if (pattern.type == PatternType.concerning) {
          final target = (150 * difficultyMultiplier).round().clamp(90, 240);
          return ChildGoal(
            id: goalId,
            title: 'Screen Time Balance',
            description:
                'Aim to keep your total screen time under $target minutes today. '
                'You can do it!',
            type: GoalType.dailyFocus,
            targetMinutes: target,
            source: GoalSource.aiGenerated,
            relatedPattern: pattern.title,
            createdAt: createdAt,
          );
        } else {
          final target = (60 * difficultyMultiplier).round().clamp(30, 120);
          return ChildGoal(
            id: goalId,
            title: 'Steady Day Goal',
            description:
                'Keep up the great balance! Target $target minutes of productive screen time today.',
            type: GoalType.dailyFocus,
            targetMinutes: target,
            source: GoalSource.aiGenerated,
            relatedPattern: pattern.title,
            createdAt: createdAt,
          );
        }

      case PatternCategory.improvement:
        final target = (60 * difficultyMultiplier).round().clamp(30, 90);
        return ChildGoal(
          id: goalId,
          title: 'Keep the Momentum!',
          description:
              'Your screen time improved! Maintain this trend with $target minutes '
              'of mindful, productive screen time today.',
          type: GoalType.dailyFocus,
          targetMinutes: target,
          source: GoalSource.aiGenerated,
          relatedPattern: pattern.title,
          createdAt: createdAt,
        );

      case PatternCategory.learningStreak:
        final target = (50 * difficultyMultiplier).round().clamp(30, 90);
        return ChildGoal(
          id: goalId,
          title: 'Learning Streak Extension',
          description:
              'Your learning streak is on fire! Keep it going with $target minutes '
              'of educational content today.',
          type: GoalType.dailyFocus,
          targetMinutes: target,
          source: GoalSource.aiGenerated,
          relatedPattern: pattern.title,
          createdAt: createdAt,
        );

      case PatternCategory.lateNight:
        return ChildGoal(
          id: goalId,
          title: 'Early Wind-Down',
          description:
              'Put screens away 30 minutes before bedtime tonight for better sleep!',
          type: GoalType.digitalBalance,
          targetMinutes: 30,
          source: GoalSource.aiGenerated,
          relatedPattern: pattern.title,
          createdAt: createdAt,
        );
    }
  }

  /// Evaluates how well the child performed on a goal.
  GoalEvaluation evaluateGoal({
    required ChildGoal goal,
    required int actualValue,
  }) {
    final now = DateTime.now();
    final ratio = goal.targetMinutes > 0
        ? actualValue / goal.targetMinutes
        : 0.0;
    final score = (ratio * 100).round().clamp(0, 100);

    EvaluationResult result;
    String feedback;

    if (score >= 90) {
      result = EvaluationResult.improved;
      feedback =
          'Amazing! You crushed this goal with $actualValue/${goal.targetMinutes}! 🎉';
    } else if (score >= 60) {
      result = EvaluationResult.maintained;
      feedback =
          'Good effort! You reached $actualValue/${goal.targetMinutes}. Keep building on this! 👍';
    } else if (score >= 25) {
      result = EvaluationResult.struggled;
      feedback =
          'You made progress with $actualValue/${goal.targetMinutes}. '
          'Every bit counts — we\'ll adjust for tomorrow! 💪';
    } else {
      result = EvaluationResult.ignored;
      feedback =
          'This goal didn\'t click today ($actualValue/${goal.targetMinutes}). '
          'Let\'s try a different approach tomorrow! 🔄';
    }

    return GoalEvaluation(
      goalId: goal.id,
      result: result,
      score: score,
      feedbackMessage: feedback,
      targetValue: goal.targetMinutes,
      actualValue: actualValue,
      evaluatedAt: now,
    );
  }
}
