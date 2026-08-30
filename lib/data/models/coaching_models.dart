import 'usage_models.dart';
import 'goal_model.dart';

// ─── Pattern Detection Models ───

enum PatternType {
  positive,
  concerning,
  neutral,
}

enum PatternCategory {
  focusTime,
  breakHabits,
  gaming,
  lateNight,
  screenTotal,
  learningStreak,
  balanceShift,
  improvement,
}

class DetectedPattern {
  final String id;
  final PatternType type;
  final PatternCategory category;
  final String title;
  final String description;
  final String suggestedAction;
  final Map<String, double> evidence; // metric name → value
  final DateTime detectedAt;

  const DetectedPattern({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    required this.suggestedAction,
    this.evidence = const {},
    required this.detectedAt,
  });

  String get emoji {
    switch (type) {
      case PatternType.positive:
        return '🌟';
      case PatternType.concerning:
        return '⚠️';
      case PatternType.neutral:
        return '📊';
    }
  }

  String get categoryLabel {
    switch (category) {
      case PatternCategory.focusTime:
        return 'Focus Time';
      case PatternCategory.breakHabits:
        return 'Break Habits';
      case PatternCategory.gaming:
        return 'Gaming';
      case PatternCategory.lateNight:
        return 'Late Night';
      case PatternCategory.screenTotal:
        return 'Screen Time';
      case PatternCategory.learningStreak:
        return 'Learning';
      case PatternCategory.balanceShift:
        return 'Balance';
      case PatternCategory.improvement:
        return 'Improvement';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category.name,
        'title': title,
        'description': description,
        'suggestedAction': suggestedAction,
        'evidence': evidence,
        'detectedAt': detectedAt.toIso8601String(),
      };

  factory DetectedPattern.fromJson(Map<String, dynamic> json) =>
      DetectedPattern(
        id: json['id'] as String,
        type: PatternType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PatternType.neutral,
        ),
        category: PatternCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => PatternCategory.screenTotal,
        ),
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        suggestedAction: json['suggestedAction'] as String? ?? '',
        evidence: Map<String, double>.from(json['evidence'] as Map? ?? {}),
        detectedAt: json['detectedAt'] != null
            ? DateTime.parse(json['detectedAt'] as String)
            : DateTime.now(),
      );
}

// ─── Goal Evaluation Models ───

enum EvaluationResult {
  improved,
  maintained,
  struggled,
  ignored,
  notYetEvaluated,
}

class GoalEvaluation {
  final String goalId;
  final EvaluationResult result;
  final int score; // 0-100
  final String feedbackMessage;
  final int targetValue;
  final int actualValue;
  final DateTime evaluatedAt;

  const GoalEvaluation({
    required this.goalId,
    required this.result,
    required this.score,
    required this.feedbackMessage,
    required this.targetValue,
    required this.actualValue,
    required this.evaluatedAt,
  });

  String get emoji {
    switch (result) {
      case EvaluationResult.improved:
        return '🎉';
      case EvaluationResult.maintained:
        return '👍';
      case EvaluationResult.struggled:
        return '💪';
      case EvaluationResult.ignored:
        return '🔄';
      case EvaluationResult.notYetEvaluated:
        return '⏳';
    }
  }

  String get resultLabel {
    switch (result) {
      case EvaluationResult.improved:
        return 'Improved!';
      case EvaluationResult.maintained:
        return 'Maintained';
      case EvaluationResult.struggled:
        return 'Keep Trying';
      case EvaluationResult.ignored:
        return 'Try Again';
      case EvaluationResult.notYetEvaluated:
        return 'In Progress';
    }
  }

  Map<String, dynamic> toJson() => {
        'goalId': goalId,
        'result': result.name,
        'score': score,
        'feedbackMessage': feedbackMessage,
        'targetValue': targetValue,
        'actualValue': actualValue,
        'evaluatedAt': evaluatedAt.toIso8601String(),
      };

  factory GoalEvaluation.fromJson(Map<String, dynamic> json) =>
      GoalEvaluation(
        goalId: json['goalId'] as String,
        result: EvaluationResult.values.firstWhere(
          (r) => r.name == json['result'],
          orElse: () => EvaluationResult.notYetEvaluated,
        ),
        score: (json['score'] as num? ?? 0).toInt(),
        feedbackMessage: json['feedbackMessage'] as String? ?? '',
        targetValue: (json['targetValue'] as num? ?? 0).toInt(),
        actualValue: (json['actualValue'] as num? ?? 0).toInt(),
        evaluatedAt: json['evaluatedAt'] != null
            ? DateTime.parse(json['evaluatedAt'] as String)
            : DateTime.now(),
      );
}

// ─── Coaching Session Models ───

enum CoachingSessionStatus {
  collecting,
  detecting,
  generating,
  attempting,
  evaluating,
  complete,
}

class UsageSnapshot {
  final int totalMinutes;
  final int focusMinutes;
  final int breakCount;
  final int unlockCount;
  final String topCategory;
  final double changeFromPrevious;

  const UsageSnapshot({
    required this.totalMinutes,
    required this.focusMinutes,
    required this.breakCount,
    this.unlockCount = 0,
    required this.topCategory,
    this.changeFromPrevious = 0.0,
  });

  factory UsageSnapshot.fromUsageSummary(UsageSummary summary) {
    return UsageSnapshot(
      totalMinutes: summary.totalMinutes,
      focusMinutes: summary.focusMinutes,
      breakCount: summary.breakCount,
      unlockCount: summary.screenUnlockCount,
      topCategory: summary.categories.isNotEmpty
          ? summary.categories.first.category
          : 'General',
      changeFromPrevious: summary.changePercentageFromYesterday,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalMinutes': totalMinutes,
        'focusMinutes': focusMinutes,
        'breakCount': breakCount,
        'unlockCount': unlockCount,
        'topCategory': topCategory,
        'changeFromPrevious': changeFromPrevious,
      };

  factory UsageSnapshot.fromJson(Map<String, dynamic> json) => UsageSnapshot(
        totalMinutes: (json['totalMinutes'] as num? ?? 0).toInt(),
        focusMinutes: (json['focusMinutes'] as num? ?? 0).toInt(),
        breakCount: (json['breakCount'] as num? ?? 0).toInt(),
        unlockCount: (json['unlockCount'] as num? ?? 0).toInt(),
        topCategory: json['topCategory'] as String? ?? 'General',
        changeFromPrevious: (json['changeFromPrevious'] as num? ?? 0).toDouble(),
      );
}

class CoachingSession {
  final String id;
  final DateTime date;
  final UsageSnapshot usageSnapshot;
  final List<DetectedPattern> patterns;
  final ChildGoal? generatedGoal;
  final GoalEvaluation? previousGoalEvaluation;
  final CoachingSessionStatus status;
  final DateTime createdAt;

  const CoachingSession({
    required this.id,
    required this.date,
    required this.usageSnapshot,
    this.patterns = const [],
    this.generatedGoal,
    this.previousGoalEvaluation,
    this.status = CoachingSessionStatus.collecting,
    required this.createdAt,
  });

  bool get isComplete => status == CoachingSessionStatus.complete;

  String get statusLabel {
    switch (status) {
      case CoachingSessionStatus.collecting:
        return 'Collecting Usage Data...';
      case CoachingSessionStatus.detecting:
        return 'Detecting Patterns...';
      case CoachingSessionStatus.generating:
        return 'Creating Your Goal...';
      case CoachingSessionStatus.attempting:
        return 'Working on Goal';
      case CoachingSessionStatus.evaluating:
        return 'Evaluating Progress...';
      case CoachingSessionStatus.complete:
        return 'Coaching Complete ✓';
    }
  }

  String get statusEmoji {
    switch (status) {
      case CoachingSessionStatus.collecting:
        return '📊';
      case CoachingSessionStatus.detecting:
        return '🔍';
      case CoachingSessionStatus.generating:
        return '🤖';
      case CoachingSessionStatus.attempting:
        return '🎯';
      case CoachingSessionStatus.evaluating:
        return '📋';
      case CoachingSessionStatus.complete:
        return '✅';
    }
  }

  CoachingSession copyWith({
    String? id,
    DateTime? date,
    UsageSnapshot? usageSnapshot,
    List<DetectedPattern>? patterns,
    ChildGoal? generatedGoal,
    GoalEvaluation? previousGoalEvaluation,
    CoachingSessionStatus? status,
    DateTime? createdAt,
  }) {
    return CoachingSession(
      id: id ?? this.id,
      date: date ?? this.date,
      usageSnapshot: usageSnapshot ?? this.usageSnapshot,
      patterns: patterns ?? this.patterns,
      generatedGoal: generatedGoal ?? this.generatedGoal,
      previousGoalEvaluation:
          previousGoalEvaluation ?? this.previousGoalEvaluation,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'usageSnapshot': usageSnapshot.toJson(),
        'patterns': patterns.map((p) => p.toJson()).toList(),
        'generatedGoal': generatedGoal?.toJson(),
        'previousGoalEvaluation': previousGoalEvaluation?.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CoachingSession.fromJson(Map<String, dynamic> json) =>
      CoachingSession(
        id: json['id'] as String,
        date: json['date'] != null
            ? DateTime.parse(json['date'] as String)
            : DateTime.now(),
        usageSnapshot: UsageSnapshot.fromJson(
            json['usageSnapshot'] as Map<String, dynamic>? ?? {}),
        patterns: (json['patterns'] as List<dynamic>? ?? [])
            .map((p) => DetectedPattern.fromJson(p as Map<String, dynamic>))
            .toList(),
        generatedGoal: json['generatedGoal'] != null
            ? ChildGoal.fromJson(json['generatedGoal'] as Map<String, dynamic>)
            : null,
        previousGoalEvaluation: json['previousGoalEvaluation'] != null
            ? GoalEvaluation.fromJson(
                json['previousGoalEvaluation'] as Map<String, dynamic>)
            : null,
        status: CoachingSessionStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => CoachingSessionStatus.complete,
        ),
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
      );
}

// ─── Coaching History ───

class CoachingHistory {
  final List<CoachingSession> sessions;

  const CoachingHistory({this.sessions = const []});

  int get totalSessions => sessions.length;

  int get streakDays {
    if (sessions.isEmpty) return 0;
    final sorted = List<CoachingSession>.from(sessions)
      ..sort((a, b) => b.date.compareTo(a.date));

    int streak = 0;
    DateTime checkDate = DateTime.now();
    for (final session in sorted) {
      final sessionDate =
          DateTime(session.date.year, session.date.month, session.date.day);
      final check =
          DateTime(checkDate.year, checkDate.month, checkDate.day);
      final diff = check.difference(sessionDate).inDays;
      if (diff <= 1) {
        streak++;
        checkDate = sessionDate;
      } else {
        break;
      }
    }
    return streak;
  }

  int get goalsCompleted {
    return sessions
        .where((s) =>
            s.previousGoalEvaluation != null &&
            (s.previousGoalEvaluation!.result == EvaluationResult.improved ||
                s.previousGoalEvaluation!.result == EvaluationResult.maintained))
        .length;
  }

  double get averageScore {
    final evaluated = sessions
        .where((s) => s.previousGoalEvaluation != null)
        .map((s) => s.previousGoalEvaluation!.score)
        .toList();
    if (evaluated.isEmpty) return 0;
    return evaluated.reduce((a, b) => a + b) / evaluated.length;
  }

  String get overallTrend {
    if (sessions.length < 3) return 'building';
    final recent = sessions.take(3).toList();
    final scores = recent
        .where((s) => s.previousGoalEvaluation != null)
        .map((s) => s.previousGoalEvaluation!.score)
        .toList();
    if (scores.length < 2) return 'building';
    if (scores.first > scores.last) return 'improving';
    if (scores.first < scores.last) return 'needs_attention';
    return 'stable';
  }

  Map<String, dynamic> toJson() => {
        'sessions': sessions.map((s) => s.toJson()).toList(),
      };

  factory CoachingHistory.fromJson(Map<String, dynamic> json) =>
      CoachingHistory(
        sessions: (json['sessions'] as List<dynamic>? ?? [])
            .map((s) => CoachingSession.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}
