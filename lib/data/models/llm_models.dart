/// Supported Prompt Types for On-Device SLM.
enum PromptType {
  childInsight,
  childMission,
  childReflection,
  parentReport,
  parentChat,
  parentTriggerExplanation;

  String get label {
    switch (this) {
      case PromptType.childInsight:
        return 'Child Insight Prompt';
      case PromptType.childMission:
        return 'Child Mission Prompt';
      case PromptType.childReflection:
        return 'Child Reflection Prompt';
      case PromptType.parentReport:
        return 'Parent Report Prompt';
      case PromptType.parentChat:
        return 'Parent Chat Prompt';
      case PromptType.parentTriggerExplanation:
        return 'Parent Trigger Explanation Prompt';
    }
  }

  String get description {
    switch (this) {
      case PromptType.childInsight:
        return 'Guides child daily summaries with positive, gamified reinforcement.';
      case PromptType.childMission:
        return 'Generates creative, balanced screen-free and focus missions.';
      case PromptType.childReflection:
        return 'Prompts mindful journaling and mood reflection without judgment.';
      case PromptType.parentReport:
        return 'Summarizes approved report aggregates objectively for parents.';
      case PromptType.parentChat:
        return 'Answers parent queries strictly using approved report facts.';
      case PromptType.parentTriggerExplanation:
        return 'Explains trigger anomalies factually without exposing hidden details.';
    }
  }
}

/// Metadata and status about a local on-device SLM model.
class ModelInfo {
  final String modelName;
  final String version;
  final int contextLimit;
  final String quantization;
  final int sizeMb;
  final bool isLoaded;
  final String engineType;
  final int memoryUsageMb;
  final bool isInstalled;

  const ModelInfo({
    required this.modelName,
    required this.version,
    required this.contextLimit,
    required this.quantization,
    required this.sizeMb,
    required this.isLoaded,
    this.engineType = 'On-Device GGUF/MediaPipe',
    this.memoryUsageMb = 280,
    this.isInstalled = true,
  });

  ModelInfo copyWith({
    String? modelName,
    String? version,
    int? contextLimit,
    String? quantization,
    int? sizeMb,
    bool? isLoaded,
    String? engineType,
    int? memoryUsageMb,
    bool? isInstalled,
  }) {
    return ModelInfo(
      modelName: modelName ?? this.modelName,
      version: version ?? this.version,
      contextLimit: contextLimit ?? this.contextLimit,
      quantization: quantization ?? this.quantization,
      sizeMb: sizeMb ?? this.sizeMb,
      isLoaded: isLoaded ?? this.isLoaded,
      engineType: engineType ?? this.engineType,
      memoryUsageMb: memoryUsageMb ?? this.memoryUsageMb,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }

  Map<String, dynamic> toJson() => {
        'modelName': modelName,
        'version': version,
        'contextLimit': contextLimit,
        'quantization': quantization,
        'sizeMb': sizeMb,
        'isLoaded': isLoaded,
        'engineType': engineType,
        'memoryUsageMb': memoryUsageMb,
        'isInstalled': isInstalled,
      };

  factory ModelInfo.fromJson(Map<String, dynamic> json) => ModelInfo(
        modelName: json['modelName'] as String? ?? 'ClearTime-SLM-Nano',
        version: json['version'] as String? ?? '1.2.0',
        contextLimit: (json['contextLimit'] as num? ?? 2048).toInt(),
        quantization: json['quantization'] as String? ?? 'q4_k_m',
        sizeMb: (json['sizeMb'] as num? ?? 380).toInt(),
        isLoaded: json['isLoaded'] as bool? ?? false,
        engineType: json['engineType'] as String? ??
            json['runtimeType'] as String? ??
            'On-Device GGUF/MediaPipe',
        memoryUsageMb: (json['memoryUsageMb'] as num? ?? 280).toInt(),
        isInstalled: json['isInstalled'] as bool? ?? true,
      );
}

/// Catalog entry for an on-device SLM.
class LocalModelCatalogEntry {
  final String id;
  final String name;
  final String version;
  final String sizeDescription;
  final int sizeMb;
  final int contextTokens;
  final String quantization;
  final String compatibility;
  final bool isInstalled;
  final bool isActive;
  final String description;

  const LocalModelCatalogEntry({
    required this.id,
    required this.name,
    required this.version,
    required this.sizeDescription,
    required this.sizeMb,
    required this.contextTokens,
    required this.quantization,
    required this.compatibility,
    this.isInstalled = false,
    this.isActive = false,
    required this.description,
  });

  LocalModelCatalogEntry copyWith({
    String? id,
    String? name,
    String? version,
    String? sizeDescription,
    int? sizeMb,
    int? contextTokens,
    String? quantization,
    String? compatibility,
    bool? isInstalled,
    bool? isActive,
    String? description,
  }) {
    return LocalModelCatalogEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      sizeDescription: sizeDescription ?? this.sizeDescription,
      sizeMb: sizeMb ?? this.sizeMb,
      contextTokens: contextTokens ?? this.contextTokens,
      quantization: quantization ?? this.quantization,
      compatibility: compatibility ?? this.compatibility,
      isInstalled: isInstalled ?? this.isInstalled,
      isActive: isActive ?? this.isActive,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'version': version,
        'sizeDescription': sizeDescription,
        'sizeMb': sizeMb,
        'contextTokens': contextTokens,
        'quantization': quantization,
        'compatibility': compatibility,
        'isInstalled': isInstalled,
        'isActive': isActive,
        'description': description,
      };

  factory LocalModelCatalogEntry.fromJson(Map<String, dynamic> json) =>
      LocalModelCatalogEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        version: json['version'] as String,
        sizeDescription: json['sizeDescription'] as String,
        sizeMb: (json['sizeMb'] as num).toInt(),
        contextTokens: (json['contextTokens'] as num).toInt(),
        quantization: json['quantization'] as String,
        compatibility: json['compatibility'] as String,
        isInstalled: json['isInstalled'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? false,
        description: json['description'] as String,
      );
}

/// Prompt Template Definition with versioning and validation state.
class PromptDefinition {
  final String id;
  final String name;
  final PromptType type;
  final String content;
  final int version;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> supportedVariables;

  const PromptDefinition({
    required this.id,
    required this.name,
    required this.type,
    required this.content,
    required this.version,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.supportedVariables = const [],
  });

  PromptDefinition copyWith({
    String? id,
    String? name,
    PromptType? type,
    String? content,
    int? version,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? supportedVariables,
  }) {
    return PromptDefinition(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      content: content ?? this.content,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      supportedVariables: supportedVariables ?? this.supportedVariables,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'content': content,
        'version': version,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'supportedVariables': supportedVariables,
      };

  factory PromptDefinition.fromJson(Map<String, dynamic> json) =>
      PromptDefinition(
        id: json['id'] as String,
        name: json['name'] as String,
        type: PromptType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => PromptType.childInsight,
        ),
        content: json['content'] as String,
        version: (json['version'] as num? ?? 1).toInt(),
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] != null
            ? DateTime.parse(json['createdAt'] as String)
            : DateTime.now(),
        updatedAt: json['updatedAt'] != null
            ? DateTime.parse(json['updatedAt'] as String)
            : DateTime.now(),
        supportedVariables:
            List<String>.from(json['supportedVariables'] as List? ?? []),
      );
}

/// Historical snapshot of a prompt version for rollback & comparison.
class PromptVersion {
  final String promptId;
  final int version;
  final String content;
  final DateTime createdAt;
  final String changeNotes;

  const PromptVersion({
    required this.promptId,
    required this.version,
    required this.content,
    required this.createdAt,
    this.changeNotes = '',
  });

  Map<String, dynamic> toJson() => {
        'promptId': promptId,
        'version': version,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'changeNotes': changeNotes,
      };

  factory PromptVersion.fromJson(Map<String, dynamic> json) => PromptVersion(
        promptId: json['promptId'] as String,
        version: (json['version'] as num).toInt(),
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        changeNotes: json['changeNotes'] as String? ?? '',
      );
}

/// Strongly-typed structured AI response output schema.
class StructuredAIResponse {
  final String answer;
  final List<String> observations;
  final List<String> evidence;
  final List<String> recommendations;
  final double confidence;
  final bool isFallback;

  const StructuredAIResponse({
    required this.answer,
    this.observations = const [],
    this.evidence = const [],
    this.recommendations = const [],
    this.confidence = 1.0,
    this.isFallback = false,
  });

  Map<String, dynamic> toJson() => {
        'answer': answer,
        'observations': observations,
        'evidence': evidence,
        'recommendations': recommendations,
        'confidence': confidence,
        'isFallback': isFallback,
      };

  factory StructuredAIResponse.fromJson(Map<String, dynamic> json) {
    return StructuredAIResponse(
      answer: json['answer'] as String? ?? '',
      observations: List<String>.from(json['observations'] as List? ?? []),
      evidence: List<String>.from(json['evidence'] as List? ?? []),
      recommendations: List<String>.from(json['recommendations'] as List? ?? []),
      confidence: (json['confidence'] as num? ?? 1.0).toDouble(),
      isFallback: json['isFallback'] as bool? ?? false,
    );
  }
}

/// Local device AI settings configuration.
class AISettings {
  final bool isAiEnabled;
  final String activeModelId;
  final double temperature;
  final int maxTokens;
  final bool enableDiagnostics;
  final int inferenceTimeoutMs;

  const AISettings({
    this.isAiEnabled = true,
    this.activeModelId = 'slm-nano-380m',
    this.temperature = 0.2,
    this.maxTokens = 512,
    this.enableDiagnostics = true,
    this.inferenceTimeoutMs = 15000,
  });

  AISettings copyWith({
    bool? isAiEnabled,
    String? activeModelId,
    double? temperature,
    int? maxTokens,
    bool? enableDiagnostics,
    int? inferenceTimeoutMs,
  }) {
    return AISettings(
      isAiEnabled: isAiEnabled ?? this.isAiEnabled,
      activeModelId: activeModelId ?? this.activeModelId,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enableDiagnostics: enableDiagnostics ?? this.enableDiagnostics,
      inferenceTimeoutMs: inferenceTimeoutMs ?? this.inferenceTimeoutMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'isAiEnabled': isAiEnabled,
        'activeModelId': activeModelId,
        'temperature': temperature,
        'maxTokens': maxTokens,
        'enableDiagnostics': enableDiagnostics,
        'inferenceTimeoutMs': inferenceTimeoutMs,
      };

  factory AISettings.fromJson(Map<String, dynamic> json) => AISettings(
        isAiEnabled: json['isAiEnabled'] as bool? ?? true,
        activeModelId: json['activeModelId'] as String? ?? 'slm-nano-380m',
        temperature: (json['temperature'] as num? ?? 0.2).toDouble(),
        maxTokens: (json['maxTokens'] as num? ?? 512).toInt(),
        enableDiagnostics: json['enableDiagnostics'] as bool? ?? true,
        inferenceTimeoutMs:
            (json['inferenceTimeoutMs'] as num? ?? 15000).toInt(),
      );
}

/// Telemetry metrics for on-device AI diagnostics (development/admin).
class AIDiagnostics {
  final String activeModel;
  final String version;
  final int inferenceTimeMs;
  final int contextTokens;
  final int responseTokens;
  final int memoryUsageMb;
  final bool networkRequired;
  final String runtimeStatus;
  final DateTime timestamp;

  const AIDiagnostics({
    required this.activeModel,
    required this.version,
    required this.inferenceTimeMs,
    required this.contextTokens,
    required this.responseTokens,
    required this.memoryUsageMb,
    this.networkRequired = false, // INVARIANT: always 100% offline
    required this.runtimeStatus,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'activeModel': activeModel,
        'version': version,
        'inferenceTimeMs': inferenceTimeMs,
        'contextTokens': contextTokens,
        'responseTokens': responseTokens,
        'memoryUsageMb': memoryUsageMb,
        'networkRequired': networkRequired,
        'runtimeStatus': runtimeStatus,
        'timestamp': timestamp.toIso8601String(),
      };

  factory AIDiagnostics.fromJson(Map<String, dynamic> json) => AIDiagnostics(
        activeModel: json['activeModel'] as String? ?? 'ClearTime-SLM-Nano',
        version: json['version'] as String? ?? '1.2.0',
        inferenceTimeMs: (json['inferenceTimeMs'] as num? ?? 320).toInt(),
        contextTokens: (json['contextTokens'] as num? ?? 450).toInt(),
        responseTokens: (json['responseTokens'] as num? ?? 120).toInt(),
        memoryUsageMb: (json['memoryUsageMb'] as num? ?? 280).toInt(),
        networkRequired: json['networkRequired'] as bool? ?? false,
        runtimeStatus: json['runtimeStatus'] as String? ?? 'Available (Offline)',
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
      );
}

/// Child Local Wellbeing AI Context
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
        additionalFacts:
            Map<String, dynamic>.from(json['additionalFacts'] as Map? ?? {}),
      );
}

/// Approved Parent Report AI Context (Zero raw timestamps, zero hidden child reflections)
class ParentAIApprovedReportContext {
  final String childNickname;
  final int totalScreenMinutes;
  final int focusMinutes;
  final double changePercentage;
  final String topCategory;
  final int goalsCompletedCount;
  final int goalsTotalCount;
  final List<String> activeTriggerAlerts;
  final String reportDateFormatted;

  const ParentAIApprovedReportContext({
    required this.childNickname,
    required this.totalScreenMinutes,
    required this.focusMinutes,
    required this.changePercentage,
    required this.topCategory,
    required this.goalsCompletedCount,
    required this.goalsTotalCount,
    this.activeTriggerAlerts = const [],
    required this.reportDateFormatted,
  });

  String toStructuredPrompt() {
    final buffer = StringBuffer();
    buffer.writeln('=== APPROVED PARENT REPORT FACTS ===');
    buffer.writeln('- Child: $childNickname');
    buffer.writeln('- Date: $reportDateFormatted');
    buffer.writeln('- Total Screen Time: $totalScreenMinutes min');
    buffer.writeln('- Focus Time: $focusMinutes min');
    buffer.writeln('- Change from Prior Period: ${changePercentage >= 0 ? "+" : ""}${changePercentage.toStringAsFixed(1)}%');
    buffer.writeln('- Primary Category: $topCategory');
    buffer.writeln('- Goals Progress: $goalsCompletedCount of $goalsTotalCount achieved');
    if (activeTriggerAlerts.isNotEmpty) {
      buffer.writeln('- Trigger Indicators: ${activeTriggerAlerts.join(", ")}');
    }
    buffer.writeln('=== STRICT INSTRUCTIONS ===');
    buffer.writeln('1. Base all observations strictly on the facts above.');
    buffer.writeln('2. Do NOT invent numbers, app names, or timestamps.');
    buffer.writeln('3. Clearly separate factual metrics from habit guidance suggestions.');
    return buffer.toString();
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isThinking;
  final StructuredAIResponse? structuredResponse;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isThinking = false,
    this.structuredResponse,
  });
}
