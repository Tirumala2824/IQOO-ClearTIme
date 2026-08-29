import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/errors/app_exceptions.dart';
import 'package:cleartime/core/security/authorization_service.dart';
import 'package:cleartime/data/models/user_profile_model.dart';
import 'package:cleartime/data/models/family_model.dart';
import 'package:cleartime/data/models/family_member_model.dart';

void main() {
  group('AuthorizationService Unit Tests', () {
    const authService = AuthorizationService();

    final parentUser = UserProfile(
      id: 'parent-123',
      email: 'parent@example.com',
      role: UserRole.parent,
      displayName: 'Parent Jane',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final childUser = UserProfile(
      id: 'child-456',
      role: UserRole.child,
      displayName: 'Child Leo',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final family = Family(
      id: 'family-abc',
      name: 'The Smiths',
      adminUserId: 'parent-123',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final members = [
      FamilyMember(
        id: 'fm-1',
        familyId: 'family-abc',
        userId: 'parent-123',
        role: FamilyRole.admin,
        joinedAt: DateTime.now(),
      ),
      FamilyMember(
        id: 'fm-2',
        familyId: 'family-abc',
        userId: 'child-456',
        role: FamilyRole.member,
        joinedAt: DateTime.now(),
      ),
    ];

    test(
        'requireAuthenticatedUser succeeds for logged-in user, throws for null',
        () {
      expect(
          authService.requireAuthenticatedUser(parentUser), equals(parentUser));
      expect(
        () => authService.requireAuthenticatedUser(null),
        throwsA(isA<AppAuthException>()),
      );
    });

    test('requireParent allows parent role, throws for child role', () {
      expect(authService.requireParent(parentUser), equals(parentUser));
      expect(
        () => authService.requireParent(childUser),
        throwsA(isA<AppAuthorizationException>()),
      );
    });

    test('requireChild allows child role, throws for parent role', () {
      expect(authService.requireChild(childUser), equals(childUser));
      expect(
        () => authService.requireChild(parentUser),
        throwsA(isA<AppAuthorizationException>()),
      );
    });

    test('requireFamilyMember enforces family membership isolation', () {
      expect(
        () =>
            authService.requireFamilyMember(parentUser, members, 'family-abc'),
        returnsNormally,
      );
      expect(
        () => authService.requireFamilyMember(childUser, members, 'family-abc'),
        returnsNormally,
      );

      // Non-member access
      final outsideUser = UserProfile(
        id: 'intruder-999',
        role: UserRole.parent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () =>
            authService.requireFamilyMember(outsideUser, members, 'family-abc'),
        throwsA(isA<AppAuthorizationException>()),
      );
    });

    test('requireFamilyAdmin verifies family administration ownership', () {
      expect(
        () => authService.requireFamilyAdmin(parentUser, family),
        returnsNormally,
      );

      final otherParent = UserProfile(
        id: 'other-parent-789',
        role: UserRole.parent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(
        () => authService.requireFamilyAdmin(otherParent, family),
        throwsA(isA<AppAuthorizationException>()),
      );
    });
  });
}
