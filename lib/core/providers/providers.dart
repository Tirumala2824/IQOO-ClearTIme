import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/env_config.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/configuration_repository.dart';
import '../../data/repositories/local_mission_repository.dart';
import '../../data/repositories/supabase_mission_repository.dart';
import '../../data/repositories/local_reward_repository.dart';
import '../../data/repositories/supabase_reward_repository.dart';
import '../../data/repositories/local_goal_repository.dart';
import '../../data/repositories/local_achievement_repository.dart';
import '../../data/repositories/local_reflection_repository.dart';
import '../../data/repositories/local_ai_settings_repository.dart';
import '../../data/repositories/local_prompt_repository.dart';
import '../../data/repositories/approved_report_repository.dart';
import '../../data/repositories/parent_report_settings_repository.dart';
import '../../data/repositories/parent_conversation_repository.dart';
import '../security/authorization_service.dart';
import '../services/abstractions/usage_data_provider.dart';
import '../services/abstractions/local_usage_store.dart';
import '../services/abstractions/local_llm_provider.dart';
import '../services/abstractions/notification_provider.dart';
import '../services/abstractions/device_provider.dart';
import '../services/task_notification_service.dart';
import '../platform/notification/native_notification_bridge.dart';
import '../platform/device/native_device_provider.dart';
import '../../services/usage/android_usage_data_provider.dart';
import '../../services/usage/usage_collector_service.dart';
import '../../services/storage/encrypted_device_store.dart';
import '../../services/storage/secure_local_usage_store.dart';
import '../../services/analytics/local_analytics_service.dart';
import '../../services/analytics/child_report_builder.dart';
import '../../services/analytics/report_comparison_service.dart';
import '../../services/analytics/local_trigger_engine.dart';
import '../../services/analytics/report_scheduler_service.dart';
import '../../services/analytics/report_request_service.dart';
import '../../services/analytics/approved_report_sync_service.dart';
import '../../services/llm/on_device_llm_provider.dart';
import '../../services/llm/local_ai_coach_service.dart';
import '../../services/llm/parent_ai_service.dart';
import '../../services/llm/local_ai_context_builder.dart';
import '../../services/llm/parent_ai_context_builder.dart';
import '../../services/llm/prompt_template_engine.dart';
import '../../services/llm/prompt_validator.dart';
import '../../services/llm/ai_response_validator.dart';
import '../../services/llm/deterministic_fallback_service.dart';
import '../../services/llm/local_model_manager.dart';
import '../../services/llm/ai_diagnostics_service.dart';
import '../../services/llm/local_model_runtime.dart';
import '../../services/llm/local_model_runtime_factory.dart';
import '../../services/llm/model_distribution_service.dart';
import '../../services/llm/local_ai_activity_service.dart';
import '../../services/push/push_notification_service.dart';
import '../../services/coaching/pattern_detection_service.dart';
import '../../services/coaching/coaching_goal_generator.dart';
import '../../services/coaching/coaching_loop_service.dart';
import '../../services/realtime/mission_realtime_service.dart';
import '../../services/storage/proof_storage_service.dart';

// --- Phase 1 Repositories ---
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return SupabaseFamilyRepository();
});

final configurationRepositoryProvider =
    Provider<ConfigurationRepository>((ref) {
  return SupabaseConfigurationRepository();
});

final authorizationServiceProvider = Provider<AuthorizationService>((ref) {
  return const AuthorizationService();
});

// --- Phase 2 Core On-Device Service Providers ---

/// Single encrypted on-device store for all private local data.
final encryptedDeviceStoreProvider = Provider<EncryptedDeviceStore>((ref) {
  final store = EncryptedDeviceStore();
  return store;
});

final localUsageStoreProvider = Provider<LocalUsageStore>((ref) {
  return SecureLocalUsageStore(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final usageDataProvider = Provider<UsageDataProvider>((ref) {
  return AndroidUsageDataProvider(
    usageStore: ref.watch(localUsageStoreProvider),
  );
});

final usageCollectorServiceProvider = Provider<UsageCollectorService>((ref) {
  return UsageCollectorService(
    usageProvider: ref.watch(usageDataProvider),
    usageStore: ref.watch(localUsageStoreProvider),
  );
});

final localMissionRepositoryProvider = Provider<LocalMissionRepository>((ref) {
  return SupabaseMissionRepository();
});

final rewardRepositoryProvider = Provider<RewardRepository>((ref) {
  return SupabaseRewardRepository();
});

final localGoalRepositoryProvider = Provider<LocalGoalRepository>((ref) {
  return EncryptedLocalGoalRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final localAchievementRepositoryProvider =
    Provider<LocalAchievementRepository>((ref) {
  return EncryptedLocalAchievementRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final localReflectionRepositoryProvider =
    Provider<LocalReflectionRepository>((ref) {
  return EncryptedLocalReflectionRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final localAnalyticsServiceProvider = Provider<LocalAnalyticsService>((ref) {
  return const LocalAnalyticsService();
});

// --- Phase 3 Local AI Control Center Providers ---

final localAISettingsRepositoryProvider =
    Provider<LocalAISettingsRepository>((ref) {
  return EncryptedLocalAISettingsRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final localPromptRepositoryProvider = Provider<LocalPromptRepository>((ref) {
  return EncryptedLocalPromptRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final promptTemplateEngineProvider = Provider<PromptTemplateEngine>((ref) {
  return const PromptTemplateEngine();
});

final promptValidatorProvider = Provider<PromptValidator>((ref) {
  final engine = ref.watch(promptTemplateEngineProvider);
  return PromptValidator(templateEngine: engine);
});

final aiResponseValidatorProvider = Provider<AIResponseValidator>((ref) {
  return const AIResponseValidator();
});

final deterministicFallbackServiceProvider =
    Provider<DeterministicFallbackService>((ref) {
  return const DeterministicFallbackService();
});

final localLlmProvider = Provider<LocalLLMProvider>((ref) {
  return OnDeviceLLMProvider(
    runtime: ref.watch(localModelRuntimeProvider),
    distribution: ref.watch(modelDistributionServiceProvider),
  );
});

final localModelRuntimeProvider = Provider<LocalModelRuntime>((ref) {
  final runtime = createLocalModelRuntime();
  return runtime;
});

final modelDistributionServiceProvider =
    Provider<ModelDistributionService>((ref) {
  return ModelDistributionService();
});

final localAiActivityServiceProvider =
    Provider<LocalAiActivityService>((ref) {
  return LocalAiActivityService(
    usageProvider: ref.watch(usageDataProvider),
    missionRepository: ref.watch(localMissionRepositoryProvider),
    runtime: ref.watch(localModelRuntimeProvider),
  );
});

/// Mutable override for the LLM provider.
final activeLlmProvider = StateProvider<LocalLLMProvider>((ref) {
  return ref.watch(localLlmProvider);
});

final localModelManagerProvider = Provider<LocalModelManager>((ref) {
  final llm = ref.watch(activeLlmProvider);
  final settingsRepo = ref.watch(localAISettingsRepositoryProvider);
  return LocalModelManager(llmProvider: llm, settingsRepo: settingsRepo);
});

final aiDiagnosticsServiceProvider = Provider<AIDiagnosticsService>((ref) {
  final llm = ref.watch(activeLlmProvider);
  return AIDiagnosticsService(llmProvider: llm);
});

final localAIContextBuilderProvider = Provider<LocalAIContextBuilder>((ref) {
  return const LocalAIContextBuilder();
});

final parentAIContextBuilderProvider = Provider<ParentAIContextBuilder>((ref) {
  return const ParentAIContextBuilder();
});

final localAICoachServiceProvider = Provider<LocalAICoachService>((ref) {
  final llm = ref.watch(activeLlmProvider);
  final builder = ref.watch(localAIContextBuilderProvider);
  final promptRepo = ref.watch(localPromptRepositoryProvider);
  final settingsRepo = ref.watch(localAISettingsRepositoryProvider);
  final engine = ref.watch(promptTemplateEngineProvider);
  final validator = ref.watch(aiResponseValidatorProvider);
  final fallback = ref.watch(deterministicFallbackServiceProvider);

  return LocalAICoachService(
    llmProvider: llm,
    contextBuilder: builder,
    promptRepo: promptRepo,
    settingsRepo: settingsRepo,
    templateEngine: engine,
    responseValidator: validator,
    fallbackService: fallback,
  );
});

final parentAIServiceProvider = Provider<ParentAIService>((ref) {
  final llm = ref.watch(activeLlmProvider);
  final builder = ref.watch(parentAIContextBuilderProvider);
  final promptRepo = ref.watch(localPromptRepositoryProvider);
  final settingsRepo = ref.watch(localAISettingsRepositoryProvider);
  final engine = ref.watch(promptTemplateEngineProvider);
  final validator = ref.watch(aiResponseValidatorProvider);
  final fallback = ref.watch(deterministicFallbackServiceProvider);

  return ParentAIService(
    llmProvider: llm,
    contextBuilder: builder,
    promptRepo: promptRepo,
    settingsRepo: settingsRepo,
    templateEngine: engine,
    responseValidator: validator,
    fallbackService: fallback,
  );
});

// --- Phase 4 Parent Reports & Local Analytics Providers ---

final approvedReportRepositoryProvider =
    Provider<ApprovedReportRepository>((ref) {
  return EncryptedApprovedReportRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final parentReportSettingsRepositoryProvider =
    Provider<ParentReportSettingsRepository>((ref) {
  return EncryptedParentReportSettingsRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final parentConversationRepositoryProvider =
    Provider<ParentConversationRepository>((ref) {
  return EncryptedParentConversationRepository(
    store: ref.watch(encryptedDeviceStoreProvider),
  );
});

final childReportBuilderProvider = Provider<ChildReportBuilder>((ref) {
  return const ChildReportBuilder();
});

final reportComparisonServiceProvider =
    Provider<ReportComparisonService>((ref) {
  return const ReportComparisonService();
});

// --- Phase 5 Triggers, Notifications & Native Integration Providers ---

final localTriggerEngineProvider = Provider<LocalTriggerEngine>((ref) {
  return LocalTriggerEngine();
});

final notificationProvider = Provider<NotificationProvider>((ref) {
  return NativeNotificationBridge();
});

final proofStorageServiceProvider = Provider<ProofStorageService>((ref) {
  return ProofStorageService();
});

final missionRealtimeServiceProvider = Provider<MissionRealtimeService>((ref) {
  return MissionRealtimeService(
    notifications: TaskNotificationService(
      notificationProvider: ref.watch(notificationProvider),
    ),
  );
});

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(configured: EnvConfig.enableFcm);
});

final deviceProvider = Provider<DeviceProvider>((ref) {
  return NativeDeviceProvider();
});

final reportSchedulerServiceProvider = Provider<ReportSchedulerService>((ref) {
  final usageStore =
      ref.watch(localUsageStoreProvider) as SecureLocalUsageStore;
  final analyticsService = ref.watch(localAnalyticsServiceProvider);
  final reportBuilder = ref.watch(childReportBuilderProvider);
  final reportRepo = ref.watch(approvedReportRepositoryProvider);
  final syncService = ref.watch(approvedReportSyncServiceProvider);

  return ReportSchedulerService(
    usageStore: usageStore,
    analyticsService: analyticsService,
    reportBuilder: reportBuilder,
    reportRepo: reportRepo,
    syncService: syncService,
  );
});

final approvedReportSyncServiceProvider =
    Provider<ApprovedReportSyncService>((ref) {
  return ApprovedReportSyncService(
    localRepo: ref.watch(approvedReportRepositoryProvider),
  );
});

final reportRequestServiceProvider = Provider<ReportRequestService>((ref) {
  return ReportRequestService();
});

// --- Phase 6 Coaching Loop Providers ---

final patternDetectionServiceProvider = Provider<PatternDetectionService>((ref) {
  return const PatternDetectionService();
});

final coachingGoalGeneratorProvider = Provider<CoachingGoalGenerator>((ref) {
  return const CoachingGoalGenerator();
});

final coachingLoopServiceProvider = Provider<CoachingLoopService>((ref) {
  final usage = ref.watch(usageDataProvider);
  final patternService = ref.watch(patternDetectionServiceProvider);
  final goalGenerator = ref.watch(coachingGoalGeneratorProvider);
  final goalRepo = ref.watch(localGoalRepositoryProvider);
  final store = ref.watch(encryptedDeviceStoreProvider);

  return CoachingLoopService(
    usageProvider: usage,
    patternService: patternService,
    goalGenerator: goalGenerator,
    goalRepo: goalRepo,
    store: store,
  );
});