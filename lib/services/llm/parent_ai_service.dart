import '../../core/services/abstractions/local_llm_provider.dart';
import '../../data/models/approved_report_model.dart';
import '../../data/models/child_profile_model.dart';
import '../../data/models/goal_model.dart';
import '../../data/models/llm_models.dart';
import '../../data/models/mission_model.dart';
import '../../data/models/reflection_model.dart';
import '../../data/models/usage_models.dart';
import '../../data/repositories/local_prompt_repository.dart';
import '../../data/repositories/local_ai_settings_repository.dart';
import '../analytics/report_comparison_service.dart';
import 'parent_ai_context_builder.dart';
import 'prompt_template_engine.dart';
import 'ai_response_validator.dart';
import 'deterministic_fallback_service.dart';

/// ParentAIService provides objective, privacy-safe report and workflow insights for parents.
///
/// Tracks full working flow: real-world missions completed/active, screen time,
/// goals, reflections, and offline activity coaching.
class ParentAIService {
  final LocalLLMProvider _llmProvider;
  final ParentAIContextBuilder _contextBuilder;
  final LocalPromptRepository _promptRepo;
  final LocalAISettingsRepository _settingsRepo;
  final PromptTemplateEngine _templateEngine;
  final AIResponseValidator _responseValidator;
  final DeterministicFallbackService _fallbackService;

  const ParentAIService({
    required LocalLLMProvider llmProvider,
    ParentAIContextBuilder contextBuilder = const ParentAIContextBuilder(),
    required LocalPromptRepository promptRepo,
    required LocalAISettingsRepository settingsRepo,
    PromptTemplateEngine templateEngine = const PromptTemplateEngine(),
    AIResponseValidator responseValidator = const AIResponseValidator(),
    DeterministicFallbackService fallbackService =
        const DeterministicFallbackService(),
  })  : _llmProvider = llmProvider,
        _contextBuilder = contextBuilder,
        _promptRepo = promptRepo,
        _settingsRepo = settingsRepo,
        _templateEngine = templateEngine,
        _responseValidator = responseValidator,
        _fallbackService = fallbackService;

  ParentAIContextBuilder get contextBuilder => _contextBuilder;

  /// Evaluates whether a query requests unavailable or forbidden child data.
  bool isQueryForUnavailableInfo(String query) {
    final lower = query.toLowerCase();
    final forbiddenPatterns = [
      'exact app at',
      'at 11:',
      'at 10:',
      'at 9:',
      'at 8:',
      'keystroke',
      'secret note',
      'incognito log',
      'browsing history search',
    ];
    return forbiddenPatterns.any((p) => lower.contains(p));
  }

  /// Primary Full-Workflow Entry Point:
  /// Handles parent questions across all existing app features: Real-World Missions,
  /// Daily Usage/Screen Time, Wellbeing Goals, Daily Reflections, and Offline Activity Suggestions.
  Future<ParentChatMessage> askAboutChildWorkflow({
    required ChildProfile child,
    required List<ChildMission> missions,
    required List<ChildGoal> goals,
    UsageSummary? todayUsage,
    UsageSummary? yesterdayUsage,
    DailyReflection? todayReflection,
    List<ApprovedReport> reports = const [],
    required String query,
  }) async {
    final now = DateTime.now();

    if (isQueryForUnavailableInfo(query)) {
      return ParentChatMessage(
        id: 'msg-missing-${now.millisecondsSinceEpoch}',
        text:
            'That information isn\'t available. ClearTime preserves child privacy and trust by focusing on wellbeing balance, offline activities, and healthy routines.',
        isUser: false,
        timestamp: now,
        isMissingDataNotice: true,
        observations: const [
          'Raw keystroke and secret background telemetry are not logged by design.'
        ],
        recommendations: [
          'Discuss digital routines openly with ${child.nickname}.'
        ],
      );
    }

    final settings = await _settingsRepo.getSettings();
    if (!settings.isAiEnabled) {
      final fallback = _fallbackService.generateParentWorkflowResponse(
        child: child,
        missions: missions,
        goals: goals,
        todayUsage: todayUsage,
        yesterdayUsage: yesterdayUsage,
        todayReflection: todayReflection,
        query: query,
      );
      return ParentChatMessage(
        id: 'msg-disabled-${now.millisecondsSinceEpoch}',
        text: fallback.answer,
        isUser: false,
        timestamp: now,
        observations: fallback.observations,
        evidence: fallback.evidence
            .map((e) => AIEvidence(
                metric: 'Workflow Fact',
                currentValue: e,
                previousValue: '-',
                change: '-',
                sourceReportId: ''))
            .toList(),
        recommendations: fallback.recommendations,
      );
    }

    try {
      final isReady = await _llmProvider.isAvailable();
      if (isReady) {
        final promptContext = _contextBuilder.buildFullWorkflowPromptContext(
          child: child,
          missions: missions,
          goals: goals,
          todayUsage: todayUsage,
          yesterdayUsage: yesterdayUsage,
          todayReflection: todayReflection,
          reports: reports,
          customQuery: query,
        );

        final rawResponse =
            await _llmProvider.generate(prompt: promptContext);
        final validation = _responseValidator.validateAndParse(rawResponse);

        if (validation.isValid && validation.structuredResponse != null) {
          final struct = validation.structuredResponse!;
          return ParentChatMessage(
            id: 'msg-ai-${now.millisecondsSinceEpoch}',
            text: struct.answer,
            isUser: false,
            timestamp: now,
            evidence: struct.evidence
                .map((e) => AIEvidence(
                    metric: 'Observation',
                    currentValue: e,
                    previousValue: '-',
                    change: '-',
                    sourceReportId: ''))
                .toList(),
            observations: struct.observations,
            recommendations: struct.recommendations,
          );
        }
      }
    } catch (_) {
      // Fall through to deterministic workflow response
    }

    // High quality deterministic fallback based on actual app data
    final fallback = _fallbackService.generateParentWorkflowResponse(
      child: child,
      missions: missions,
      goals: goals,
      todayUsage: todayUsage,
      yesterdayUsage: yesterdayUsage,
      todayReflection: todayReflection,
      query: query,
    );

    return ParentChatMessage(
      id: 'msg-workflow-${now.millisecondsSinceEpoch}',
      text: fallback.answer,
      isUser: false,
      timestamp: now,
      evidence: fallback.evidence
          .map((e) => AIEvidence(
              metric: 'App Data',
              currentValue: e,
              previousValue: '-',
              change: '-',
              sourceReportId: ''))
          .toList(),
      observations: fallback.observations,
      recommendations: fallback.recommendations,
    );
  }

  /// Analyzes an approved parent report context using local SLM (Phase 3 compatibility).
  Future<StructuredAIResponse> analyzeReport({
    required ParentAIApprovedReportContext context,
    String? customQuery,
  }) async {
    final settings = await _settingsRepo.getSettings();
    if (!settings.isAiEnabled) {
      return _fallbackService.generateDisabledMessage();
    }

    final isReady = await _llmProvider.isAvailable();
    if (!isReady) {
      return _fallbackService.generateParentFallback(
        context: context,
        query: customQuery,
      );
    }

    try {
      final promptType = customQuery != null
          ? PromptType.parentChat
          : PromptType.parentReport;
      final promptDef =
          await _promptRepo.getActivePromptByType(promptType);

      final template = promptDef?.content ??
          'Analyze approved summary facts for {{child_name}} on {{report_date}}: Screen time {{screen_time}}, Focus {{focus_time}}, Goal progress {{goal_progress}}. Provide an objective summary and habit coaching suggestions.';

      final hours = context.totalScreenMinutes ~/ 60;
      final mins = context.totalScreenMinutes % 60;
      final screenTimeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      final vars = {
        'child_name': context.childNickname,
        'report_date': context.reportDateFormatted,
        'screen_time': screenTimeStr,
        'previous_screen_time': '2h 15m',
        'usage_change':
            '${context.changePercentage >= 0 ? "+" : ""}${context.changePercentage.toStringAsFixed(1)}%',
        'focus_time': '${context.focusMinutes}m',
        'top_category': context.topCategory,
        'goal_progress':
            '${context.goalsTotalCount > 0 ? ((context.goalsCompletedCount / context.goalsTotalCount) * 100).round() : 100}%',
      };

      final renderedPrompt = _templateEngine.render(template, vars);

      final buffer = StringBuffer();
      buffer.writeln(renderedPrompt);
      buffer.writeln(context.toStructuredPrompt());
      if (customQuery != null && customQuery.trim().isNotEmpty) {
        buffer.writeln('Parent Question: $customQuery');
      }
      buffer.writeln('Local AI Assistant Response (in JSON structured format):');

      final rawResponse = await _llmProvider.generate(prompt: buffer.toString());

      final validation = _responseValidator.validateAndParse(rawResponse);
      if (validation.isValid && validation.structuredResponse != null) {
        return validation.structuredResponse!;
      }

      return _fallbackService.generateParentFallback(
        context: context,
        query: customQuery,
      );
    } catch (_) {
      return _fallbackService.generateParentFallback(
        context: context,
        query: customQuery,
      );
    }
  }

  /// Asks a question about a specific ApprovedReport using local LLM.
  Future<ParentChatMessage> askAboutApprovedReport({
    required ApprovedReport report,
    required String query,
  }) async {
    final now = DateTime.now();

    if (isQueryForUnavailableInfo(query)) {
      return ParentChatMessage(
        id: 'msg-missing-${now.millisecondsSinceEpoch}',
        text:
            'That information isn\'t available in the approved wellbeing report. ClearTime only shares privacy-approved aggregate summaries to safeguard healthy trust.',
        isUser: false,
        timestamp: now,
        isMissingDataNotice: true,
        observations: const [
          'Raw timestamps, detailed app event streams, and private child reflections are intentionally omitted from parent summaries.'
        ],
        recommendations: [
          'Discuss daily routine balance openly with ${report.childNickname} rather than monitoring individual app launches.'
        ],
      );
    }

    final settings = await _settingsRepo.getSettings();
    if (!settings.isAiEnabled) {
      return ParentChatMessage(
        id: 'msg-fallback-${now.millisecondsSinceEpoch}',
        text: report.summaryText,
        isUser: false,
        timestamp: now,
        evidence: [
          AIEvidence(
            metric: 'Screen Time',
            currentValue: report.facts.formattedTotalTime,
            previousValue:
                '${report.facts.previousScreenMinutes ~/ 60}h ${report.facts.previousScreenMinutes % 60}m',
            change:
                '${report.facts.changePercentage >= 0 ? "+" : ""}${report.facts.changePercentage}%',
            sourceReportId: report.id,
          ),
        ],
        observations: [
          'Focus learning time: ${report.facts.formattedFocusTime}',
          'Mindful pauses taken: ${report.facts.breakCount}',
        ],
      );
    }

    try {
      final contextPrompt = _contextBuilder.buildReportPromptContext(
        report: report,
        customQuery: query,
      );

      final rawResponse = await _llmProvider.generate(prompt: contextPrompt);
      final validation = _responseValidator.validateAndParse(rawResponse);

      if (validation.isValid && validation.structuredResponse != null) {
        final struct = validation.structuredResponse!;
        final evidenceList = <AIEvidence>[
          AIEvidence(
            metric: 'Screen Time',
            currentValue: report.facts.formattedTotalTime,
            previousValue:
                '${report.facts.previousScreenMinutes ~/ 60}h ${report.facts.previousScreenMinutes % 60}m',
            change:
                '${report.facts.changePercentage >= 0 ? "+" : ""}${report.facts.changePercentage}%',
            sourceReportId: report.id,
          ),
          if (report.facts.focusMinutes > 0)
            AIEvidence(
              metric: 'Focus Time',
              currentValue: report.facts.formattedFocusTime,
              previousValue: '${report.facts.previousFocusMinutes}m',
              change:
                  '${report.facts.focusChangePercentage >= 0 ? "+" : ""}${report.facts.focusChangePercentage}%',
              sourceReportId: report.id,
            ),
        ];

        return ParentChatMessage(
          id: 'msg-ai-${now.millisecondsSinceEpoch}',
          text: struct.answer,
          isUser: false,
          timestamp: now,
          evidence: evidenceList,
          observations: struct.observations,
          recommendations: struct.recommendations,
        );
      }

      return ParentChatMessage(
        id: 'msg-fallback-${now.millisecondsSinceEpoch}',
        text: report.summaryText,
        isUser: false,
        timestamp: now,
        observations: [
          'Factual screen time: ${report.facts.formattedTotalTime}',
          'Focus engagement: ${report.facts.formattedFocusTime}',
        ],
      );
    } catch (_) {
      return ParentChatMessage(
        id: 'msg-err-${now.millisecondsSinceEpoch}',
        text: report.summaryText,
        isUser: false,
        timestamp: now,
      );
    }
  }

  /// Explains a ReportComparisonResult using local LLM.
  Future<ParentChatMessage> explainComparison({
    required ReportComparisonResult comparison,
    String? query,
  }) async {
    final now = DateTime.now();
    final effectiveQuery = query ??
        'Explain the key changes between these reports and what habit patterns to discuss.';

    final settings = await _settingsRepo.getSettings();
    if (!settings.isAiEnabled) {
      return ParentChatMessage(
        id: 'cmp-fallback-${now.millisecondsSinceEpoch}',
        text: comparison.deterministicSummary,
        isUser: false,
        timestamp: now,
        evidence: comparison.evidence,
        observations: [
          'Overall trend direction: ${comparison.overallTrendDirection}',
          'Screen time variance: ${comparison.screenTimeDiffFormatted}',
        ],
      );
    }

    try {
      final contextPrompt = _contextBuilder.buildComparisonPromptContext(
        comparison: comparison,
        customQuery: effectiveQuery,
      );

      final rawResponse = await _llmProvider.generate(prompt: contextPrompt);
      final validation = _responseValidator.validateAndParse(rawResponse);

      if (validation.isValid && validation.structuredResponse != null) {
        final struct = validation.structuredResponse!;
        return ParentChatMessage(
          id: 'cmp-ai-${now.millisecondsSinceEpoch}',
          text: struct.answer,
          isUser: false,
          timestamp: now,
          evidence: comparison.evidence,
          observations: struct.observations,
          recommendations: struct.recommendations,
        );
      }

      return ParentChatMessage(
        id: 'cmp-fallback-${now.millisecondsSinceEpoch}',
        text: comparison.deterministicSummary,
        isUser: false,
        timestamp: now,
        evidence: comparison.evidence,
      );
    } catch (_) {
      return ParentChatMessage(
        id: 'cmp-err-${now.millisecondsSinceEpoch}',
        text: comparison.deterministicSummary,
        isUser: false,
        timestamp: now,
        evidence: comparison.evidence,
      );
    }
  }

  /// Preset suggested queries for parents.
  static const List<String> suggestedParentQueries = [
    'What tasks did my child complete yesterday?',
    'What activity should I assign today?',
    'How is today\'s screen time and focus balance?',
    'What wellbeing goals are in progress?',
    'Suggest a fun outdoor weekend activity',
    'What habit routines improved this week?',
  ];
}
