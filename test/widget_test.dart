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
import 'package:cleartime/features/onboarding/screens/onboarding_screen.dart';

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

      // Verify branding and titles
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
        'ChildDashboardScreen renders positive wellbeing quests and points',
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
      expect(find.text('Your Mindful Habits'), findsOneWidget);
    });
  });
}
