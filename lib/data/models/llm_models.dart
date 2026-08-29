class ModelInfo {
  final String modelName;
  final String version;
  final int contextLimit;
  final String quantization;
  final int sizeMb;
  final bool isLoaded;
  final String engineType;

  const ModelInfo({
    required this.modelName,
    required this.version,
    required this.contextLimit,
    required this.quantization,
    required this.sizeMb,
    required this.isLoaded,
    this.engineType = 'On-Device GGUF/MediaPipe',
  });

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'version': version,
        'contextLimit': contextLimit,
        'quantization': quantization,
        'sizeMb': sizeMb,
        'isLoaded': isLoaded,
        'engineType': engineType,
      };

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
        modelName: json['modelName'] as String? ?? 'ClearTime-SLM-Nano',
        version: json['version'] as String? ?? '1.0.0',
        contextLimit: (json['contextLimit'] as num? ?? 2048).toInt(),
        quantization: json['quantization'] as String? ?? 'q4_k_m',
        sizeMb: (json['sizeMb'] as num? ?? 450).toInt(),
        isLoaded: json['isLoaded'] as bool? ?? false,
        engineType: json['engineType'] as String? ??
            json['runtimeType'] as String? ??
            'On-Device GGUF/MediaPipe',
      );
}

class AIContext {
  final int todayUsageMinutes;
  final int focusMinutes;
  final int breakCount;
  final double usageChangePercentage;
  final String topCategory;
  final int completedMissions;
  final int activeGoalsCount;
  final String? recentReflection;
  final Map<String, dynamic> additionalFacts;

  const AIContext({
    required this.todayUsageMinutes,
    required this.focusMinutes,
    required this.breakCount,
    required this.usageChangePercentage,
    required this.topCategory,
    required this.completedMissions,
    required this.activeGoalsCount,
    this.recentReflection,
    this.additionalFacts = const {},
  });

  String toStructuredPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('=== TODAY LOCAL WELLBEING FACTS (DO NOT MODIFY METRICS) ===');
    buffer.writeln('- Total Screen Time: $todayUsageMinutes minutes');
    buffer.writeln('- Focused Learning/Reading Time: $focusMinutes minutes');
    buffer.writeln('- Mindful Breaks Taken: $breakCount breaks');
    buffer.writeln('- Usage Change vs Yesterday: ${usageChangePercentage.toStringAsFixed(1)}%');
    buffer.writeln('- Top App Category: $topCategory');
    buffer.writeln('- Completed Quests: $completedMissions');
    buffer.writeln('- Active Wellbeing Goals: $activeGoalsCount');
    if (recentReflection != null) {
      buffer.writeln('- Child Daily Reflection: $recentReflection');
    }
    buffer.writeln('=== END OF FACTS ===');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'todayUsageMinutes': todayUsageMinutes,
        'focusMinutes': focusMinutes,
        'breakCount': breakCount,
        'usageChangePercentage': usageChangePercentage,
        'topCategory': topCategory,
        'completedMissions': completedMissions,
        'activeGoalsCount': activeGoalsCount,
        'recentReflection': recentReflection,
        'additionalFacts': additionalFacts,
      };

  factory AIContext.fromJson(Map<String, dynamic> json) => AIContext(
        todayUsageMinutes: (json['todayUsageMinutes'] as num).toInt(),
        focusMinutes: (json['focusMinutes'] as num).toInt(),
        breakCount: (json['breakCount'] as num).toInt(),
        usageChangePercentage: (json['usageChangePercentage'] as num).toDouble(),
        topCategory: json['topCategory'] as String? ?? 'Learning',
        completedMissions: (json['completedMissions'] as num? ?? 0).toInt(),
        activeGoalsCount: (json['activeGoalsCount'] as num? ?? 0).toInt(),
        recentReflection: json['recentReflection'] as String?,
        additionalFacts: Map<String, dynamic>.from(json['additionalFacts'] as Map? ?? {}),
      );
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isThinking;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isThinking = false,
  });
}
