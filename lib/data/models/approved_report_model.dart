/// Report period granularity.
enum ReportPeriod {
  daily,
  weekly,
  monthly;

  String get label {
    switch (this) {
      case ReportPeriod.daily:
        return 'Daily Summary';
      case ReportPeriod.weekly:
        return 'Weekly Digest';
      case ReportPeriod.monthly:
        return 'Monthly Overview';
    }
  }

  static ReportPeriod fromString(String value) {
    switch (value.toUpperCase()) {
      case 'DAILY':
        return ReportPeriod.daily;
      case 'WEEKLY':
        return ReportPeriod.weekly;
      case 'MONTHLY':
        return ReportPeriod.monthly;
      default:
        return ReportPeriod.weekly;
    }
  }

  String toDbString() => name.toUpperCase();
}

/// Report detail level.
enum ReportDetailLevel {
  summary,
  detailed,
  insightsOnly;

  String get label {
    switch (this) {
      case ReportDetailLevel.summary:
        return 'Summary';
      case ReportDetailLevel.detailed:
        return 'Detailed';
      case ReportDetailLevel.insightsOnly:
        return 'Insights Only';
    }
  }

  static ReportDetailLevel fromString(String value) {
    switch (value.toUpperCase()) {
      case 'SUMMARY':
        return ReportDetailLevel.summary;
      case 'DETAILED':
        return ReportDetailLevel.detailed;
      case 'INSIGHTS_ONLY':
      case 'INSIGHTSONLY':
        return ReportDetailLevel.insightsOnly;
      default:
        return ReportDetailLevel.summary;
    }
  }

  String toDbString() {
    switch (this) {
      case ReportDetailLevel.summary:
        return 'SUMMARY';
      case ReportDetailLevel.detailed:
        return 'DETAILED';
      case ReportDetailLevel.insightsOnly:
        return 'INSIGHTS_ONLY';
    }
  }
}

/// Configurable approved sharing categories.
enum ReportCategory {
  overallUsage,
  usageTrend,
  focusTime,
  breakSummary,
  goals,
  achievements,
  categorySummary;

  String get label {
    switch (this) {
      case ReportCategory.overallUsage:
        return 'Overall Screen Time';
      case ReportCategory.usageTrend:
        return 'Usage Trends & Change';
      case ReportCategory.focusTime:
        return 'Focus & Learning Time';
      case ReportCategory.breakSummary:
        return 'Mindful Movement Breaks';
      case ReportCategory.goals:
        return 'Wellbeing Goals Progress';
      case ReportCategory.achievements:
        return 'Unlocked Milestone Badges';
      case ReportCategory.categorySummary:
        return 'Category Distribution (High-Level)';
    }
  }

  static ReportCategory fromString(String value) {
    switch (value.toLowerCase()) {
      case 'overallusage':
      case 'overall_usage':
        return ReportCategory.overallUsage;
      case 'usagetrend':
      case 'usage_trend':
        return ReportCategory.usageTrend;
      case 'focustime':
      case 'focus_time':
        return ReportCategory.focusTime;
      case 'breaksummary':
      case 'break_summary':
        return ReportCategory.breakSummary;
      case 'goals':
        return ReportCategory.goals;
      case 'achievements':
        return ReportCategory.achievements;
      case 'categorysummary':
      case 'category_summary':
        return ReportCategory.categorySummary;
      default:
        return ReportCategory.overallUsage;
    }
  }
}

/// Epistemological type distinction for AI output and report items.
enum InsightType {
  fact,
  inference,
  suggestion;

  String get label {
    switch (this) {
      case InsightType.fact:
        return 'FACT';
      case InsightType.inference:
        return 'INFERENCE';
      case InsightType.suggestion:
        return 'SUGGESTION';
    }
  }
}

/// A structured evidence fact proving an AI or report claim.
class AIEvidence {
  final String metric;
  final String currentValue;
  final String previousValue;
  final String change;
  final String sourceReportId;

  const AIEvidence({
    required this.metric,
    required this.currentValue,
    required this.previousValue,
    required this.change,
    this.sourceReportId = '',
  });

  Map<String, dynamic> toJson() => {
        'metric': metric,
        'currentValue': currentValue,
        'previousValue': previousValue,
        'change': change,
        'sourceReportId': sourceReportId,
      };

  factory AIEvidence.fromJson(Map<String, dynamic> json) => AIEvidence(
        metric: json['metric'] as String? ?? '',
        currentValue: json['currentValue'] as String? ?? '',
        previousValue: json['previousValue'] as String? ?? '',
        change: json['change'] as String? ?? '',
        sourceReportId: json['sourceReportId'] as String? ?? '',
      );
}

/// An approved insight card within a report.
class ApprovedInsight {
  final String id;
  final InsightType type;
  final ReportCategory category;
  final String title;
  final String description;
  final AIEvidence? evidence;
  final double confidence;

  const ApprovedInsight({
    required this.id,
    required this.type,
    required this.category,
    required this.title,
    required this.description,
    this.evidence,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'category': category.name,
        'title': title,
        'description': description,
        'evidence': evidence?.toJson(),
        'confidence': confidence,
      };

  factory ApprovedInsight.fromJson(Map<String, dynamic> json) =>
      ApprovedInsight(
        id: json['id'] as String,
        type: InsightType.values
                .where((t) => t.name == json['type'])
                .firstOrNull ??
            InsightType.fact,
        category: ReportCategory.fromString(json['category'] as String? ?? ''),
        title: json['title'] as String,
        description: json['description'] as String,
        evidence: json['evidence'] != null
            ? AIEvidence.fromJson(json['evidence'] as Map<String, dynamic>)
            : null,
        confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      );
}

/// Numerical, privacy-filtered ground truth facts calculated on the child device.
/// NEVER contains raw app packages, raw event timestamps, or raw timeline entries.
class ReportFacts {
  final int totalScreenMinutes;
  final int previousScreenMinutes;
  final double changePercentage;
  final int focusMinutes;
  final int previousFocusMinutes;
  final double focusChangePercentage;
  final int breakCount;
  final int previousBreakCount;
  final int goalsCompletedCount;
  final int goalsTotalCount;
  final int achievementsUnlockedCount;
  final List<String> achievementsUnlocked;
  final Map<String, int> categoryBreakdown; // Category -> total minutes (sanitized)
  final String usageTrend; // 'increasing', 'decreasing', 'stable'
  final int screenUnlockCount;

  const ReportFacts({
    required this.totalScreenMinutes,
    this.previousScreenMinutes = 0,
    this.changePercentage = 0.0,
    required this.focusMinutes,
    this.previousFocusMinutes = 0,
    this.focusChangePercentage = 0.0,
    required this.breakCount,
    this.previousBreakCount = 0,
    this.goalsCompletedCount = 0,
    this.goalsTotalCount = 0,
    this.achievementsUnlockedCount = 0,
    this.achievementsUnlocked = const [],
    this.categoryBreakdown = const {},
    this.usageTrend = 'stable',
    this.screenUnlockCount = 0,
  });

  String get formattedTotalTime {
    final hours = totalScreenMinutes ~/ 60;
    final minutes = totalScreenMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedFocusTime {
    final hours = focusMinutes ~/ 60;
    final minutes = focusMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Map<String, dynamic> toJson() => {
        'totalScreenMinutes': totalScreenMinutes,
        'previousScreenMinutes': previousScreenMinutes,
        'changePercentage': changePercentage,
        'focusMinutes': focusMinutes,
        'previousFocusMinutes': previousFocusMinutes,
        'focusChangePercentage': focusChangePercentage,
        'breakCount': breakCount,
        'previousBreakCount': previousBreakCount,
        'goalsCompletedCount': goalsCompletedCount,
        'goalsTotalCount': goalsTotalCount,
        'achievementsUnlockedCount': achievementsUnlockedCount,
        'achievementsUnlocked': achievementsUnlocked,
        'categoryBreakdown': categoryBreakdown,
        'usageTrend': usageTrend,
        'screenUnlockCount': screenUnlockCount,
      };

  factory ReportFacts.fromJson(Map<String, dynamic> json) => ReportFacts(
        totalScreenMinutes: (json['totalScreenMinutes'] as num? ?? 0).toInt(),
        previousScreenMinutes:
            (json['previousScreenMinutes'] as num? ?? 0).toInt(),
        changePercentage:
            (json['changePercentage'] as num? ?? 0.0).toDouble(),
        focusMinutes: (json['focusMinutes'] as num? ?? 0).toInt(),
        previousFocusMinutes:
            (json['previousFocusMinutes'] as num? ?? 0).toInt(),
        focusChangePercentage:
            (json['focusChangePercentage'] as num? ?? 0.0).toDouble(),
        breakCount: (json['breakCount'] as num? ?? 0).toInt(),
        previousBreakCount: (json['previousBreakCount'] as num? ?? 0).toInt(),
        goalsCompletedCount:
            (json['goalsCompletedCount'] as num? ?? 0).toInt(),
        goalsTotalCount: (json['goalsTotalCount'] as num? ?? 0).toInt(),
        achievementsUnlockedCount:
            (json['achievementsUnlockedCount'] as num? ?? 0).toInt(),
        achievementsUnlocked: List<String>.from(
            json['achievementsUnlocked'] as List? ?? []),
        categoryBreakdown:
            Map<String, int>.from(json['categoryBreakdown'] as Map? ?? {}),
        usageTrend: json['usageTrend'] as String? ?? 'stable',
        screenUnlockCount: (json['screenUnlockCount'] as num? ?? 0).toInt(),
      );
}

/// Immutable Approved Report snapshot emitted by the child device privacy pipeline.
class ApprovedReport {
  final String id;
  final String childId;
  final String childNickname;
  final String familyId;
  final ReportPeriod period;
  final DateTime periodStart;
  final DateTime periodEnd;
  final ReportDetailLevel detailLevel;
  final Set<ReportCategory> categories;
  final ReportFacts facts;
  final List<ApprovedInsight> insights;
  final String summaryText;
  final String? aiExplanation;
  final Map<String, dynamic> understandActSections;
  final String contextVersion;
  final String privacyFilterVersion;
  final String analyticsVersion;
  final String configVersion;
  final DateTime createdAt;
  final bool isSnapshot;

  const ApprovedReport({
    required this.id,
    required this.childId,
    required this.childNickname,
    required this.familyId,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    this.detailLevel = ReportDetailLevel.summary,
    this.categories = const {
      ReportCategory.overallUsage,
      ReportCategory.usageTrend,
      ReportCategory.focusTime,
      ReportCategory.breakSummary,
      ReportCategory.goals,
      ReportCategory.achievements,
      ReportCategory.categorySummary,
    },
    required this.facts,
    this.insights = const [],
    required this.summaryText,
    this.aiExplanation,
    this.understandActSections = const {},
    this.contextVersion = '1.0.0',
    this.privacyFilterVersion = '1.0.0',
    this.analyticsVersion = '1.0.0',
    this.configVersion = '1.0.0',
    required this.createdAt,
    this.isSnapshot = true,
  });

  String get formattedPeriodTitle {
    final startStr = '${periodStart.month}/${periodStart.day}';
    final endStr = '${periodEnd.month}/${periodEnd.day}';
    switch (period) {
      case ReportPeriod.daily:
        return 'Daily Report ($startStr)';
      case ReportPeriod.weekly:
        return 'Weekly Digest ($startStr - $endStr)';
      case ReportPeriod.monthly:
        return 'Monthly Overview (${periodStart.month}/${periodStart.year})';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'childNickname': childNickname,
        'familyId': familyId,
        'period': period.toDbString(),
        'periodStart': periodStart.toIso8601String(),
        'periodEnd': periodEnd.toIso8601String(),
        'detailLevel': detailLevel.toDbString(),
        'categories': categories.map((c) => c.name).toList(),
        'facts': facts.toJson(),
        'insights': insights.map((i) => i.toJson()).toList(),
        'summaryText': summaryText,
        'aiExplanation': aiExplanation,
        'understand_act': understandActSections,
        'contextVersion': contextVersion,
        'privacyFilterVersion': privacyFilterVersion,
        'analyticsVersion': analyticsVersion,
        'configVersion': configVersion,
        'createdAt': createdAt.toIso8601String(),
        'isSnapshot': isSnapshot,
      };

  factory ApprovedReport.fromJson(Map<String, dynamic> json) => ApprovedReport(
        id: json['id'] as String,
        childId: json['childId'] as String? ?? json['child_id'] as String? ?? '',
        childNickname: json['childNickname'] as String? ??
            json['child_nickname'] as String? ??
            'Child',
        familyId:
            json['familyId'] as String? ?? json['family_id'] as String? ?? '',
        period:
            ReportPeriod.fromString(json['period'] as String? ?? 'WEEKLY'),
        periodStart: DateTime.parse(
            json['periodStart'] as String? ?? json['period_start'] as String),
        periodEnd: DateTime.parse(
            json['periodEnd'] as String? ?? json['period_end'] as String),
        detailLevel: ReportDetailLevel.fromString(
            json['detailLevel'] as String? ?? json['detail_level'] as String? ?? 'SUMMARY'),
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((c) => ReportCategory.fromString(c as String))
            .toSet(),
        facts: ReportFacts.fromJson(
            json['facts'] as Map<String, dynamic>? ?? {}),
        insights: (json['insights'] as List<dynamic>? ?? [])
            .map((i) => ApprovedInsight.fromJson(i as Map<String, dynamic>))
            .toList(),
        summaryText: json['summaryText'] as String? ??
            json['summary_text'] as String? ??
            '',
        aiExplanation: json['aiExplanation'] as String? ??
            json['ai_explanation'] as String?,
        understandActSections: Map<String, dynamic>.from(
            json['understand_act'] as Map? ?? {}),
        contextVersion: json['contextVersion'] as String? ??
            json['context_version'] as String? ??
            '1.0.0',
        privacyFilterVersion: json['privacyFilterVersion'] as String? ??
            json['privacy_filter_version'] as String? ??
            '1.0.0',
        analyticsVersion: json['analyticsVersion'] as String? ??
            json['analytics_version'] as String? ??
            '1.0.0',
        configVersion: json['configVersion'] as String? ??
            json['config_version'] as String? ??
            '1.0.0',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : json['created_at'] != null
                ? DateTime.parse(json['created_at'] as String)
                : DateTime.now(),
        isSnapshot: json['isSnapshot'] as bool? ??
            json['is_snapshot'] as bool? ??
            true,
      );

  ApprovedReport copyWith({
    String? aiExplanation,
    List<ApprovedInsight>? insights,
    String? summaryText,
    Map<String, dynamic>? understandActSections,
  }) {
    return ApprovedReport(
      id: id,
      childId: childId,
      childNickname: childNickname,
      familyId: familyId,
      period: period,
      periodStart: periodStart,
      periodEnd: periodEnd,
      detailLevel: detailLevel,
      categories: categories,
      facts: facts,
      insights: insights ?? this.insights,
      summaryText: summaryText ?? this.summaryText,
      aiExplanation: aiExplanation ?? this.aiExplanation,
      understandActSections: understandActSections ?? this.understandActSections,
      contextVersion: contextVersion,
      privacyFilterVersion: privacyFilterVersion,
      analyticsVersion: analyticsVersion,
      configVersion: configVersion,
      createdAt: createdAt,
      isSnapshot: isSnapshot,
    );
  }
}

/// Parent report configuration settings model.
class ParentReportSettings {
  final bool reportsEnabled;
  final ReportPeriod frequency;
  final ReportDetailLevel detail;
  final bool notificationsEnabled;
  final Set<ReportCategory> categories;

  const ParentReportSettings({
    this.reportsEnabled = true,
    this.frequency = ReportPeriod.weekly,
    this.detail = ReportDetailLevel.summary,
    this.notificationsEnabled = true,
    this.categories = const {
      ReportCategory.overallUsage,
      ReportCategory.usageTrend,
      ReportCategory.focusTime,
      ReportCategory.breakSummary,
      ReportCategory.goals,
      ReportCategory.achievements,
      ReportCategory.categorySummary,
    },
  });

  Map<String, dynamic> toJson() => {
        'reportsEnabled': reportsEnabled,
        'frequency': frequency.toDbString(),
        'detail': detail.toDbString(),
        'notificationsEnabled': notificationsEnabled,
        'categories': categories.map((c) => c.name).toList(),
      };

  factory ParentReportSettings.fromJson(Map<String, dynamic> json) =>
      ParentReportSettings(
        reportsEnabled: json['reportsEnabled'] as bool? ?? true,
        frequency: ReportPeriod.fromString(
            json['frequency'] as String? ?? 'WEEKLY'),
        detail: ReportDetailLevel.fromString(
            json['detail'] as String? ?? 'SUMMARY'),
        notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
        categories: (json['categories'] as List<dynamic>? ?? [])
            .map((c) => ReportCategory.fromString(c as String))
            .toSet(),
      );

  ParentReportSettings copyWith({
    bool? reportsEnabled,
    ReportPeriod? frequency,
    ReportDetailLevel? detail,
    bool? notificationsEnabled,
    Set<ReportCategory>? categories,
  }) {
    return ParentReportSettings(
      reportsEnabled: reportsEnabled ?? this.reportsEnabled,
      frequency: frequency ?? this.frequency,
      detail: detail ?? this.detail,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      categories: categories ?? this.categories,
    );
  }
}

/// Local Parent AI Conversation Model (stored 100% on parent device).
class ParentAIConversation {
  final String id;
  final String childId;
  final String title;
  final List<ParentChatMessage> messages;
  final List<String> selectedReportIds;
  final String contextVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ParentAIConversation({
    required this.id,
    required this.childId,
    required this.title,
    this.messages = const [],
    this.selectedReportIds = const [],
    this.contextVersion = '1.0.0',
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'childId': childId,
        'title': title,
        'messages': messages.map((m) => m.toJson()).toList(),
        'selectedReportIds': selectedReportIds,
        'contextVersion': contextVersion,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory ParentAIConversation.fromJson(Map<String, dynamic> json) =>
      ParentAIConversation(
        id: json['id'] as String,
        childId: json['childId'] as String,
        title: json['title'] as String? ?? 'Conversation',
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((m) => ParentChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        selectedReportIds:
            List<String>.from(json['selectedReportIds'] as List? ?? []),
        contextVersion: json['contextVersion'] as String? ?? '1.0.0',
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
      );

  ParentAIConversation copyWith({
    String? title,
    List<ParentChatMessage>? messages,
    List<String>? selectedReportIds,
    DateTime? updatedAt,
  }) {
    return ParentAIConversation(
      id: id,
      childId: childId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      selectedReportIds: selectedReportIds ?? this.selectedReportIds,
      contextVersion: contextVersion,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Message within a Parent AI conversation.
class ParentChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<AIEvidence> evidence;
  final List<String> observations;
  final List<String> recommendations;
  final bool isMissingDataNotice;

  const ParentChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.evidence = const [],
    this.observations = const [],
    this.recommendations = const [],
    this.isMissingDataNotice = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'isUser': isUser,
        'timestamp': timestamp.toIso8601String(),
        'evidence': evidence.map((e) => e.toJson()).toList(),
        'observations': observations,
        'recommendations': recommendations,
        'isMissingDataNotice': isMissingDataNotice,
      };

  factory ParentChatMessage.fromJson(Map<String, dynamic> json) =>
      ParentChatMessage(
        id: json['id'] as String,
        text: json['text'] as String? ?? '',
        isUser: json['isUser'] as bool? ?? false,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        evidence: (json['evidence'] as List<dynamic>? ?? [])
            .map((e) => AIEvidence.fromJson(e as Map<String, dynamic>))
            .toList(),
        observations:
            List<String>.from(json['observations'] as List? ?? []),
        recommendations:
            List<String>.from(json['recommendations'] as List? ?? []),
        isMissingDataNotice: json['isMissingDataNotice'] as bool? ?? false,
      );
}
