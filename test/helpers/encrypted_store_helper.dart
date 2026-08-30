import 'dart:io';

import 'package:cleartime/services/storage/encrypted_device_store.dart';
import 'package:cleartime/data/models/goal_model.dart';
import 'package:cleartime/data/models/llm_models.dart';
import 'package:cleartime/data/models/reflection_model.dart';
import 'package:cleartime/data/repositories/approved_report_repository.dart';
import 'package:cleartime/data/repositories/local_ai_settings_repository.dart';
import 'package:cleartime/data/repositories/local_goal_repository.dart';
import 'package:cleartime/data/repositories/local_reflection_repository.dart';
import 'package:cleartime/data/repositories/parent_conversation_repository.dart';
import 'package:cleartime/data/repositories/parent_report_settings_repository.dart';
import 'package:cleartime/services/storage/secure_local_usage_store.dart';

/// Creates an encrypted store on a per-call temp directory with an in-memory
/// key store (the platform keychain is unavailable under `flutter test`).
Future<EncryptedDeviceStore> createTestDeviceStore() async {
  final dir = Directory.systemTemp.createTempSync('cleartime_test_hive');
  final store = EncryptedDeviceStore(
    keyStore: InMemorySecretKeyStore(),
    storagePath: dir.path,
  );
  await store.initialize();
  return store;
}

Future<LocalGoalRepository> createTestGoalRepo(EncryptedDeviceStore store) async {
  return EncryptedLocalGoalRepository(store: store);
}

Future<LocalReflectionRepository> createTestReflectionRepo(
    EncryptedDeviceStore store) async {
  return EncryptedLocalReflectionRepository(store: store);
}

Future<LocalAISettingsRepository> createTestSettingsRepo(
    EncryptedDeviceStore store) async {
  return EncryptedLocalAISettingsRepository(store: store);
}

Future<ParentConversationRepository> createTestConversationRepo(
    EncryptedDeviceStore store) async {
  return EncryptedParentConversationRepository(store: store);
}

Future<ParentReportSettingsRepository> createTestReportSettingsRepo(
    EncryptedDeviceStore store) async {
  return EncryptedParentReportSettingsRepository(store: store);
}

Future<ApprovedReportRepository> createTestReportRepo(
    EncryptedDeviceStore store) async {
  return EncryptedApprovedReportRepository(store: store);
}

SecureLocalUsageStore createTestUsageStore(EncryptedDeviceStore store) {
  return SecureLocalUsageStore(store: store);
}

/// Common fixtures reused across tests (explicit test data, never seeded by
/// the application itself).
ChildGoal sampleGoal({
  String id = 'goal-1',
  GoalSource source = GoalSource.aiGenerated,
}) {
  return ChildGoal(
    id: id,
    title: 'Focused learning time',
    description: 'Reach 30 minutes of focused learning.',
    type: GoalType.dailyFocus,
    targetMinutes: 30,
    source: source,
    createdAt: DateTime.now(),
  );
}

DailyReflection sampleReflection({String id = 'ref-1'}) {
  final now = DateTime.now();
  return DailyReflection(
    id: id,
    date: DateTime(now.year, now.month, now.day),
    mood: ReflectionMood.productive,
    notes: 'Felt focused today.',
    createdAt: now,
  );
}

PromptDefinition samplePrompt({
  String id = 'prompt-test',
  PromptType type = PromptType.childInsight,
}) {
  final now = DateTime.now();
  return PromptDefinition(
    id: id,
    name: 'Test prompt',
    type: type,
    content: 'Be kind to {{child_name}}.',
    version: 1,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    supportedVariables: const ['child_name'],
  );
}