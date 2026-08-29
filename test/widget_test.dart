import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Family;
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cleartime/core/providers/providers.dart';
import 'package:cleartime/data/models/user_profile_model.dart';
import 'package:cleartime/data/models/child_profile_model.dart';
import 'package:cleartime/data/models/family_model.dart';
import 'package:cleartime/data/models/family_invitation_model.dart';
import 'package:cleartime/data/repositories/auth_repository.dart';
import 'package:cleartime/data/repositories/family_repository.dart';
import 'package:cleartime/data/repositories/configuration_repository.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/data/models/notification_pref_model.dart';
import 'package:cleartime/data/models/privacy_setting_model.dart';
import 'package:cleartime/features/authentication/screens/login_screen.dart';
import 'package:cleartime/features/child/screens/child_dashboard_screen.dart';
import 'package:cleartime/features/child/screens/child_missions_screen.dart';
import 'package:cleartime/features/child/screens/child_goals_screen.dart';
import 'package:cleartime/features/child/screens/child_progress_screen.dart';
import 'package:cleartime/features/child/screens/child_ai_screen.dart';
import 'package:cleartime/features/onboarding/screens/onboarding_screen.dart';
import 'package:cleartime/features/parent/screens/local_ai_settings_screen.dart';
import 'package:cleartime/features/parent/screens/model_manager_screen.dart';
import 'package:cleartime/features/parent/screens/prompt_manager_screen.dart';
import 'package:cleartime/features/parent/screens/prompt_editor_screen.dart';
import 'package:cleartime/features/parent/screens/ai_diagnostics_screen.dart';
import 'package:cleartime/features/parent/screens/parent_ai_screen.dart';
import 'package:cleartime/features/parent/screens/parent_reports_screen.dart';
import 'package:cleartime/features/parent/screens/parent_report_compare_screen.dart';
import 'package:cleartime/features/parent/controllers/parent_dashboard_controller.dart';
import 'package:cleartime/features/family/controllers/invitation_controller.dart';
import 'package:cleartime/features/family/screens/invite_child_screen.dart';
import 'package:cleartime/features/family/screens/join_family_screen.dart';
import 'package:cleartime/services/usage/demo_usage_data_provider.dart';

class FakeAuthRepository implements AuthRepository {
  final UserProfile? _profile;

  FakeAuthRepository([this._profile]);

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  User? get currentAuthUser => null;

  @override
  Future<UserProfile?> getCurrentUserProfile() async => _profile;

  @override
  Future<UserProfile> registerProfile({
    required String userId,
    required UserRole role,
    String? email,
    String? phoneNumber,
    String? displayName,
  }) async {
    return UserProfile(
      id: userId,
      role: role,
      email: email,
      phoneNumber: phoneNumber,
      displayName: displayName,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> sendPhoneOtp({required String phoneNumber}) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<UserProfile> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
    required UserRole role,
    String? displayName,
  }) async {
    return UserProfile(
      id: 'test-user-id',
      role: role,
      phoneNumber: phoneNumber,
      displayName: displayName ?? 'Test User',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

class FakeFamilyRepository implements FamilyRepository {
  @override
  Future<Family> createFamily({
    required String name,
    required String adminUserId,
  }) async {
    return Family(
      id: 'fam-1',
      name: name,
      adminUserId: adminUserId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<FamilyInvitation> generateInvitation({
    required String familyId,
    required String createdBy,
  }) async {
    return FamilyInvitation(
      id: 'inv-1',
      familyId: familyId,
      createdBy: createdBy,
      invitationCode: '7X9K2M4P',
      qrPayload: 'qr',
      expiresAt: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<FamilyInvitation>> getActiveInvitations(String familyId) async =>
      [];

  @override
  Future<ChildProfile?> getChildProfileForUser(String userId) async {
    return ChildProfile(
      id: 'cp-1',
      userId: userId,
      familyId: 'fam-1',
      nickname: 'Explorer',
      age: 10,
      avatarIndex: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChildProfile>> getChildrenForFamily(String familyId) async => [];

  @override
  Future<Family?> getFamilyForUser(String userId) async {
    return Family(
      id: 'fam-1',
      name: 'The Bright Family',
      adminUserId: 'parent-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<ChildProfile> redeemInvitation({
    required String invitationCode,
    required String childUserId,
    required String nickname,
    int? age,
    int avatarIndex = 0,
  }) async {
    return ChildProfile(
      id: 'cp-1',
      userId: childUserId,
      familyId: 'fam-1',
      nickname: nickname,
      age: age,
      avatarIndex: avatarIndex,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {}
}

class FakeConfigurationRepository implements ConfigurationRepository {
  @override
  Future<ReportConfiguration> createReportConfiguration(
          ReportConfiguration config) async =>
      config;

  @override
  Future<TriggerConfiguration> createTriggerConfiguration(
          TriggerConfiguration config) async =>
      config;

  @override
  Future<void> deleteReportConfiguration(String id) async {}

  @override
  Future<void> deleteTriggerConfiguration(String id) async {}

  @override
  Future<NotificationPreference?> getNotificationPreferences(
          String userId) async =>
      null;

  @override
  Future<PrivacySetting?> getPrivacySettings({
    required String familyId,
    required String userId,
  }) async =>
      null;

  @override
  Future<List<ReportConfiguration>> getReportConfigurations(
          String familyId) async =>
      [];

  @override
  Future<List<TriggerConfiguration>> getTriggerConfigurations(
          String familyId) async =>
      [];

  @override
  Future<NotificationPreference> updateNotificationPreferences(
          NotificationPreference prefs) async =>
      prefs;

  @override
  Future<PrivacySetting> updatePrivacySettings(PrivacySetting settings) async =>
      settings;

  @override
  Future<ReportConfiguration> updateReportConfiguration(
          ReportConfiguration config) async =>
      config;

  @override
  Future<TriggerConfiguration> updateTriggerConfiguration(
          TriggerConfiguration config) async =>
      config;
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ClearTime UI Widget Tests', () {
    testWidgets('LoginScreen renders branding, role selector, and inputs',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ClearTime'), findsOneWidget);
      expect(
          find.text('Digital wellbeing designed for families'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Child'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets(
        'OnboardingScreen renders family creation input and privacy notice',
        (WidgetTester tester) async {
      final fakeUser = UserProfile(
        id: 'parent-123',
        role: UserRole.parent,
        email: 'parent@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(fakeUser)),
            familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
            configurationRepositoryProvider
                .overrideWithValue(FakeConfigurationRepository()),
          ],
          child: const MaterialApp(
            home: OnboardingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Your Family Hub'), findsOneWidget);
      expect(find.text('Family Name'), findsOneWidget);
      expect(find.text('Privacy-First Architecture'), findsOneWidget);
      expect(find.text('Create Family & Continue'), findsOneWidget);
    });

    testWidgets(
        'ChildDashboardScreen renders positive wellbeing quests, points, and metrics',
        (WidgetTester tester) async {
      final fakeChild = UserProfile(
        id: 'child-123',
        role: UserRole.child,
        displayName: 'Leo',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(fakeChild)),
            familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
            configurationRepositoryProvider
                .overrideWithValue(FakeConfigurationRepository()),
            usageDataProvider.overrideWithValue(DemoUsageDataProvider()),
          ],
          child: const MaterialApp(
            home: ChildDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Explorer'), findsOneWidget);
      expect(find.text('Mindful Hero Level 1'), findsOneWidget);
      expect(find.text('Today’s Wellbeing Quests'), findsOneWidget);
      expect(find.text('Total Screen'), findsOneWidget);
      expect(find.text('Focus Time'), findsOneWidget);
    });

    testWidgets('ChildMissionsScreen renders quest list and category badges',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChildMissionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Wellbeing Quests 🎯'), findsOneWidget);
      expect(find.text('20-Minute Focus Quest'), findsOneWidget);
      expect(find.text('Study Sprint'), findsOneWidget);
    });

    testWidgets('ChildGoalsScreen renders goals and summary tiles',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChildGoalsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Wellbeing Goals 🎯'), findsOneWidget);
      expect(find.text('Total Goals'), findsOneWidget);
      expect(find.text('Daily Focus Goal'), findsOneWidget);
    });

    testWidgets('ChildProgressScreen renders badges and XP',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChildProgressScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Wellbeing Badges 🏆'), findsOneWidget);
      expect(find.text('Focus Starter'), findsOneWidget);
      expect(find.text('Break Master'), findsOneWidget);
    });

    testWidgets('ChildAiScreen renders offline buddy chat with prompt chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ChildAiScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Wellbeing Buddy 🤖'), findsOneWidget);
      expect(find.text('100% Offline AI'), findsOneWidget);
      expect(find.text('How did I do today?'), findsOneWidget);
      expect(find.text('Help me focus.'), findsOneWidget);
    });

    // --- Phase 3 Local AI Control Center Tests ---

    testWidgets('LocalAiSettingsScreen renders AI status, active model, and benchmark runner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LocalAiSettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Local AI Control Center'), findsOneWidget);
      expect(find.text('Zero Cloud LLM Dependency'), findsOneWidget);
      expect(find.text('AI Status: Running Locally'), findsOneWidget);
      expect(find.text('Active Model'), findsOneWidget);
      expect(find.text('Model Manager'), findsOneWidget);
      expect(find.text('Prompt Manager & Templates'), findsOneWidget);
      expect(find.text('Local AI Diagnostics'), findsOneWidget);
    });

    testWidgets('ModelManagerScreen renders tabs for installed models and catalog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ModelManagerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Local Model Manager'), findsOneWidget);
      expect(find.textContaining('Installed'), findsOneWidget);
      expect(find.textContaining('Available Catalog'), findsOneWidget);
      expect(find.text('ClearTime-SLM-Nano'), findsOneWidget);
    });

    testWidgets('PromptManagerScreen renders prompt template cards and actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PromptManagerScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Prompt Manager'), findsOneWidget);
      expect(find.text('Child Daily Insight'), findsOneWidget);
    });

    testWidgets('PromptEditorScreen renders variable chips and preview',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: PromptEditorScreen(promptId: 'prompt-child-insight'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Insert Supported Variables'), findsOneWidget);
      expect(find.text('{{child_name}}'), findsOneWidget);
      expect(find.text('{{screen_time}}'), findsOneWidget);
      expect(find.text('Rendered Template Preview (Local Data Context)'), findsOneWidget);
      expect(find.text('Test Prompt Locally'), findsOneWidget);
    });

    testWidgets('AiDiagnosticsScreen renders latency, tokens, and RAM telemetry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AiDiagnosticsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Local AI Diagnostics'), findsOneWidget);
      expect(find.text('Inference Latency'), findsOneWidget);
      expect(find.text('RAM Consumption'), findsOneWidget);
      expect(find.text('Network Transfer'), findsOneWidget);
      expect(find.text('Privacy Boundaries Verification'), findsOneWidget);
    });

    testWidgets('ParentAiScreen renders parent assistant with offline banner',
        (WidgetTester tester) async {
      final fakeParent = UserProfile(
        id: 'parent-123',
        role: UserRole.parent,
        email: 'parent@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(fakeParent)),
            familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
            configurationRepositoryProvider
                .overrideWithValue(FakeConfigurationRepository()),
            usageDataProvider.overrideWithValue(DemoUsageDataProvider()),
          ],
          child: const MaterialApp(
            home: ParentAiScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Parent AI Assistant'), findsOneWidget);
      expect(find.textContaining('100% On-Device Inference'), findsOneWidget);
      expect(find.text('Why did usage change this week?'), findsOneWidget);
    });

    testWidgets('ParentReportsScreen renders period tabs and configure button',
        (WidgetTester tester) async {
      final fakeParent = UserProfile(
        id: 'parent-123',
        role: UserRole.parent,
        email: 'parent@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(fakeParent)),
            familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
            configurationRepositoryProvider
                .overrideWithValue(FakeConfigurationRepository()),
          ],
          child: const MaterialApp(
            home: ParentReportsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Approved Wellbeing Reports'), findsOneWidget);
      expect(find.text('Daily Summaries'), findsOneWidget);
      expect(find.text('Weekly Digests'), findsOneWidget);
      expect(find.text('Configure Reports'), findsOneWidget);
    });

    testWidgets('ParentReportCompareScreen renders comparison cards and deterministic summary',
        (WidgetTester tester) async {
      final fakeParent = UserProfile(
        id: 'parent-123',
        role: UserRole.parent,
        email: 'parent@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(fakeParent)),
            familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
            configurationRepositoryProvider
                .overrideWithValue(FakeConfigurationRepository()),
          ],
          child: const MaterialApp(
            home: ParentReportCompareScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump();

      expect(find.text('Compare Wellbeing Reports'), findsOneWidget);
      expect(find.text('Deterministic Variance Metrics'), findsOneWidget);
      expect(find.text('Explain Comparison with On-Device AI'), findsOneWidget);
    });

    testWidgets('InviteChildScreen renders pairing instructions and code generation',
        (WidgetTester tester) async {
      final fakeParent = UserProfile(
        id: 'parent-123',
        role: UserRole.parent,
        email: 'parent@example.com',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider
              .overrideWithValue(FakeAuthRepository(fakeParent)),
          familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
          configurationRepositoryProvider
              .overrideWithValue(FakeConfigurationRepository()),
        ],
      );
      await container
          .read(parentDashboardControllerProvider.notifier)
          .loadDashboard('parent-123');
      await container
          .read(invitationControllerProvider.notifier)
          .loadActiveInvitations('fam-1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: InviteChildScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('Invite Child to Family'), findsOneWidget);
      expect(find.text('Pair Child Device Securely'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('JoinFamilyScreen renders invitation code input, avatar selector, and quick-fill test button',
        (WidgetTester tester) async {
      final fakeChild = UserProfile(
        id: 'child-123',
        role: UserRole.child,
        displayName: 'Leo',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider
                .overrideWithValue(FakeAuthRepository(fakeChild)),
            familyRepositoryProvider.overrideWithValue(FakeFamilyRepository()),
          ],
          child: const MaterialApp(
            home: JoinFamilyScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Join Family Space'), findsOneWidget);
      expect(find.text('Welcome to ClearTime!'), findsOneWidget);
      expect(find.text('Invitation Code'), findsOneWidget);
      expect(find.text('Fill Test Code (TEST2026)'), findsOneWidget);
      expect(find.text('Your Nickname'), findsOneWidget);
      expect(find.text('Choose an Avatar'), findsOneWidget);
      expect(find.text('Join Family Hub'), findsOneWidget);
    });
  });
}
