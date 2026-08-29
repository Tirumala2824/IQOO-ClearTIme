import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/child_profile_model.dart';
import 'package:cleartime/data/models/family_model.dart';
import 'package:cleartime/data/models/family_invitation_model.dart';
import 'package:cleartime/data/repositories/family_repository.dart';
import 'package:cleartime/features/family/controllers/invitation_controller.dart';
import 'package:cleartime/core/errors/app_exceptions.dart';
import 'package:cleartime/core/security/secure_token_generator.dart';

class MockFamilyRepository implements FamilyRepository {
  final List<FamilyInvitation> invitations = [];
  bool shouldThrowError = false;

  @override
  Future<Family> createFamily({
    required String name,
    required String adminUserId,
  }) async {
    return Family(
      id: 'fam-100',
      name: name,
      adminUserId: adminUserId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<Family?> getFamilyForUser(String userId) async {
    return Family(
      id: 'fam-100',
      name: 'Bright Family',
      adminUserId: userId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<List<ChildProfile>> getChildrenForFamily(String familyId) async => [];

  @override
  Future<ChildProfile?> getChildProfileForUser(String userId) async => null;

  @override
  Future<FamilyInvitation> generateInvitation({
    required String familyId,
    required String createdBy,
  }) async {
    if (shouldThrowError) {
      throw const AppDatabaseException('Database connection failed');
    }
    final code = SecureTokenGenerator.generateInvitationCode();
    final invitation = FamilyInvitation(
      id: 'inv-${invitations.length + 1}',
      familyId: familyId,
      createdBy: createdBy,
      invitationCode: code,
      qrPayload: SecureTokenGenerator.generateQrPayload(
        invitationCode: code,
        familyId: familyId,
      ),
      expiresAt: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
      status: InvitationStatus.active,
    );
    invitations.insert(0, invitation);
    return invitation;
  }

  @override
  Future<List<FamilyInvitation>> getActiveInvitations(String familyId) async {
    if (shouldThrowError) {
      throw const AppDatabaseException('Database error loading invitations');
    }
    return invitations.where((i) => i.status == InvitationStatus.active).toList();
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    if (shouldThrowError) {
      throw const AppDatabaseException('Database error revoking invitation');
    }
    final index = invitations.indexWhere((i) => i.id == invitationId);
    if (index != -1) {
      invitations[index] = FamilyInvitation(
        id: invitations[index].id,
        familyId: invitations[index].familyId,
        createdBy: invitations[index].createdBy,
        invitationCode: invitations[index].invitationCode,
        qrPayload: invitations[index].qrPayload,
        expiresAt: invitations[index].expiresAt,
        createdAt: invitations[index].createdAt,
        status: InvitationStatus.revoked,
      );
    }
  }

  @override
  Future<ChildProfile> redeemInvitation({
    required String invitationCode,
    required String childUserId,
    required String nickname,
    int? age,
    int avatarIndex = 0,
  }) async {
    if (shouldThrowError) {
      throw const AppInvitationException('Invalid or expired invitation code.');
    }
    final cleanCode = SecureTokenGenerator.parseInvitationCode(invitationCode);
    if (cleanCode == 'INVALID9') {
      throw const AppInvitationException('Invalid invitation code');
    }

    return ChildProfile(
      id: 'cp-999',
      userId: childUserId,
      familyId: 'fam-100',
      nickname: nickname,
      age: age ?? 10,
      avatarIndex: avatarIndex,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

void main() {
  group('Parent-Child Invitation Code Unit Tests', () {
    late MockFamilyRepository mockRepository;
    late InvitationController controller;

    setUp(() {
      mockRepository = MockFamilyRepository();
      controller = InvitationController(mockRepository);
    });

    test('Initial InvitationState has empty defaults', () {
      expect(controller.state.latestInvitation, isNull);
      expect(controller.state.activeInvitations, isEmpty);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNull);
      expect(controller.state.isRedeemed, isFalse);
    });

    test('Parent generates secure 8-character invitation code successfully',
        () async {
      final inv = await controller.generateInvitation(
        familyId: 'fam-100',
        parentUserId: 'parent-001',
      );

      expect(inv, isNotNull);
      expect(inv!.invitationCode.length, equals(8));
      expect(inv.status, equals(InvitationStatus.active));
      expect(controller.state.latestInvitation, equals(inv));
      expect(controller.state.activeInvitations.length, equals(1));
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.errorMessage, isNull);
    });

    test('Parent loads active family invitations', () async {
      await controller.generateInvitation(
        familyId: 'fam-100',
        parentUserId: 'parent-001',
      );
      await controller.generateInvitation(
        familyId: 'fam-100',
        parentUserId: 'parent-001',
      );

      await controller.loadActiveInvitations('fam-100');
      expect(controller.state.activeInvitations.length, equals(2));
    });

    test('Parent revokes an invitation code', () async {
      final inv = await controller.generateInvitation(
        familyId: 'fam-100',
        parentUserId: 'parent-001',
      );

      expect(controller.state.activeInvitations.length, equals(1));
      await controller.revokeInvitation(inv!.id, 'fam-100');
      expect(controller.state.activeInvitations.length, equals(0));
    });

    test('Child redeems invitation code and links to family successfully',
        () async {
      final childProfile = await controller.redeemInvitation(
        invitationCode: '7X9K2M4P',
        childUserId: 'child-user-007',
        nickname: 'Leo',
        age: 11,
        avatarIndex: 2,
      );

      expect(childProfile, isNotNull);
      expect(childProfile!.nickname, equals('Leo'));
      expect(childProfile.familyId, equals('fam-100'));
      expect(childProfile.avatarIndex, equals(2));
      expect(controller.state.isRedeemed, isTrue);
      expect(controller.state.errorMessage, isNull);
    });

    test('Child redeeming invalid invitation code sets error message',
        () async {
      final childProfile = await controller.redeemInvitation(
        invitationCode: 'INVALID9',
        childUserId: 'child-user-007',
        nickname: 'Leo',
      );

      expect(childProfile, isNull);
      expect(controller.state.isRedeemed, isFalse);
      expect(controller.state.errorMessage, contains('Invalid invitation code'));
    });

    test('Handles repository database errors during generation gracefully',
        () async {
      mockRepository.shouldThrowError = true;
      final inv = await controller.generateInvitation(
        familyId: 'fam-100',
        parentUserId: 'parent-001',
      );

      expect(inv, isNull);
      expect(controller.state.errorMessage, contains('Database connection failed'));
      expect(controller.state.isLoading, isFalse);
    });
  });
}
