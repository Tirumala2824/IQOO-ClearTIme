import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/family_repository.dart';
import '../../data/repositories/configuration_repository.dart';
import '../../data/repositories/local_mission_repository.dart';
import '../../data/repositories/local_goal_repository.dart';
import '../../data/repositories/local_achievement_repository.dart';
import '../../data/repositories/local_reflection_repository.dart';
import '../security/authorization_service.dart';
import '../services/abstractions/usage_data_provider.dart';
import '../services/abstractions/local_usage_store.dart';
import '../services/abstractions/local_llm_provider.dart';
import '../../services/usage/android_usage_data_provider.dart';
import '../../services/usage/demo_usage_data_provider.dart';
import '../../services/storage/secure_local_usage_store.dart';
import '../../services/analytics/local_analytics_service.dart';
import '../../services/llm/on_device_llm_provider.dart';
import '../../services/llm/local_ai_coach_service.dart';
import '../../services/llm/local_ai_context_builder.dart';

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

/// Toggle to switch between real Android platform channel and Demo mock adapter for previews
final useDemoDataProvider = StateProvider<bool>((ref) => false);

final usageDataProvider = Provider<UsageDataProvider>((ref) {
  final useDemo = ref.watch(useDemoDataProvider);
  if (useDemo) {
    return DemoUsageDataProvider();
  }
  return AndroidUsageDataProvider();
});

final localUsageStoreProvider = Provider<LocalUsageStore>((ref) {
  return SecureLocalUsageStore();
});

final localMissionRepositoryProvider = Provider<LocalMissionRepository>((ref) {
  return InMemoryLocalMissionRepository();
});

final localGoalRepositoryProvider = Provider<LocalGoalRepository>((ref) {
  return InMemoryLocalGoalRepository();
});

final localAchievementRepositoryProvider =
    Provider<LocalAchievementRepository>((ref) {
  return InMemoryLocalAchievementRepository();
});

final localReflectionRepositoryProvider =
    Provider<LocalReflectionRepository>((ref) {
  return InMemoryLocalReflectionRepository();
});

final localAnalyticsServiceProvider = Provider<LocalAnalyticsService>((ref) {
  return const LocalAnalyticsService();
});

final localLlmProvider = Provider<LocalLLMProvider>((ref) {
  return OnDeviceLLMProvider();
});

final localAIContextBuilderProvider = Provider<LocalAIContextBuilder>((ref) {
  return const LocalAIContextBuilder();
});

final localAICoachServiceProvider = Provider<LocalAICoachService>((ref) {
  final llm = ref.watch(localLlmProvider);
  final builder = ref.watch(localAIContextBuilderProvider);
  return LocalAICoachService(llmProvider: llm, contextBuilder: builder);
});
