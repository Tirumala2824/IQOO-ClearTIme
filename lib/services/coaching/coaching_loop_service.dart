import '../../core/services/abstractions/usage_data_provider.dart';
import '../../data/models/coaching_models.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/usage_models.dart';
import '../../data/repositories/local_goal_repository.dart';
import 'pattern_detection_service.dart';
import 'coaching_goal_generator.dart';
import 'package:uuid/uuid.dart';

/// CoachingLoopService orchestrates the complete ClearTime AI Coaching Loop:
///
/// Usage → Detect Patterns → Create Goal → Attempt Goal →
/// Measure Results → Evaluate Progress → Generate New Goal → Repeat
///
/// 100% on-device. Never sends data externally.
class CoachingLoopService {
  final UsageDataProvider _usageProvider;
  final PatternDetectionService _patternService;
  final CoachingGoalGenerator _goalGenerator;
  final LocalGoalRepository _goalRepo;

  /// In-memory coaching session history (pre-seeded with 7-day demo data).
  final List<CoachingSession> _sessions = [];

  CoachingLoopService({
    required UsageDataProvider usageProvider,
    required PatternDetectionService patternService,
    required CoachingGoalGenerator goalGenerator,
    required LocalGoalRepository goalRepo,
  })  : _usageProvider = usageProvider,
        _patternService = patternService,
        _goalGenerator = goalGenerator,
        _goalRepo = goalRepo;

  // ─── Step 1: Collect Usage Data ───

  Future<UsageSummary> collectUsageData() async {
    return await _usageProvider.getTodayUsage();
  }

  // ─── Step 2: Detect Patterns ───

  Future<List<DetectedPattern>> detectPatterns(UsageSummary usage) async {
    final weeklyHistory = await _usageProvider.getWeeklyUsage();
    return _patternService.detectPatterns(
      todayUsage: usage,
      weeklyHistory: weeklyHistory,
    );
  }

  // ─── Step 3: Generate Personalized Goal ───

  Future<ChildGoal> generateGoal(List<DetectedPattern> patterns) async {
    final previousGoals = await _goalRepo.getGoals();
    final previousEvaluations = _sessions
        .where((s) => s.previousGoalEvaluation != null)
        .map((s) => s.previousGoalEvaluation!)
        .toList();

    return _goalGenerator.generateGoal(
      patterns: patterns,
      previousEvaluations: previousEvaluations,
      previousGoals: previousGoals,
    );
  }

  // ─── Step 4 & 5: Evaluate Previous Goal Progress ───

  Future<GoalEvaluation?> evaluatePreviousGoal(UsageSummary usage) async {
    // Find the most recent AI-generated active goal
    final goals = await _goalRepo.getGoals();
    final activeAIGoals = goals
        .where(
            (g) => g.source == GoalSource.aiGenerated && g.status != GoalStatus.completed)
        .toList();

    if (activeAIGoals.isEmpty) return null;

    final goal = activeAIGoals.last;

    // Determine actual value based on goal type
    int actualValue;
    switch (goal.type) {
      case GoalType.dailyFocus:
        actualValue = usage.focusMinutes;
        break;
      case GoalType.breakGoal:
        actualValue = usage.breakCount;
        break;
      case GoalType.digitalBalance:
        // For balance goals, success = keeping gaming UNDER target
        final gamingMin = usage.categories
            .where((c) => c.category.toLowerCase().contains('game'))
            .fold<int>(0, (s, c) => s + c.totalMinutes);
        // Invert: if gaming is under target, score is high
        actualValue = gamingMin <= goal.targetMinutes
            ? goal.targetMinutes
            : (goal.targetMinutes - (gamingMin - goal.targetMinutes)).clamp(0, goal.targetMinutes);
        break;
      case GoalType.weeklyFocus:
        actualValue = usage.focusMinutes;
        break;
    }

    final evaluation = _goalGenerator.evaluateGoal(
      goal: goal,
      actualValue: actualValue,
    );

    // Update the goal with evaluation result and mark completed
    await _goalRepo.updateGoalProgress(goal.id, actualValue);
    final updated = await _goalRepo.getGoalById(goal.id);
    if (updated != null) {
      await _goalRepo.saveGoal(updated.copyWith(
        evaluationResult: evaluation.result.name,
        status: GoalStatus.completed,
        updatedAt: DateTime.now(),
      ));
    }

    return evaluation;
  }

  // ─── Step 6 & 7: Run Full Coaching Loop ───

  /// Executes the complete coaching loop and returns the session.
  ///
  /// Called automatically on dashboard load and manually via button.
  Future<CoachingSession> runFullLoop() async {
    const uuid = Uuid();
    final now = DateTime.now();
    final sessionId = 'cs-${uuid.v4().substring(0, 8)}';
    final today = DateTime(now.year, now.month, now.day);

    // Check if we already ran today
    final existingToday = _sessions.where((s) =>
        s.date.year == today.year &&
        s.date.month == today.month &&
        s.date.day == today.day &&
        s.isComplete);
    if (existingToday.isNotEmpty) {
      return existingToday.last;
    }

    // Step 1: Collect
    var session = CoachingSession(
      id: sessionId,
      date: today,
      usageSnapshot: const UsageSnapshot(
        totalMinutes: 0,
        focusMinutes: 0,
        breakCount: 0,
        topCategory: 'Loading...',
      ),
      status: CoachingSessionStatus.collecting,
      createdAt: now,
    );

    final usage = await collectUsageData();
    session = session.copyWith(
      usageSnapshot: UsageSnapshot.fromUsageSummary(usage),
      status: CoachingSessionStatus.detecting,
    );

    // Step 2: Detect patterns
    final patterns = await detectPatterns(usage);
    session = session.copyWith(
      patterns: patterns,
      status: CoachingSessionStatus.evaluating,
    );

    // Step 3: Evaluate previous goal (if any)
    final evaluation = await evaluatePreviousGoal(usage);
    session = session.copyWith(
      previousGoalEvaluation: evaluation,
      status: CoachingSessionStatus.generating,
    );

    // Step 4: Generate new personalized goal
    final newGoal = await generateGoal(patterns);
    await _goalRepo.saveGoal(newGoal);

    session = session.copyWith(
      generatedGoal: newGoal,
      status: CoachingSessionStatus.complete,
    );

    // Store session
    _sessions.add(session);

    return session;
  }

  // ─── History Access ───

  CoachingHistory getCoachingHistory() {
    return CoachingHistory(sessions: List.unmodifiable(_sessions));
  }

  CoachingSession? getTodaySession() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todaySessions = _sessions.where((s) =>
        s.date.year == today.year &&
        s.date.month == today.month &&
        s.date.day == today.day);
    return todaySessions.isNotEmpty ? todaySessions.last : null;
  }

  List<DetectedPattern> getLatestPatterns() {
    if (_sessions.isEmpty) return [];
    return _sessions.last.patterns;
  }
}
