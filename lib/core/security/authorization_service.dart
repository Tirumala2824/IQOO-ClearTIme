import '../errors/app_exceptions.dart';
import '../../data/models/user_profile_model.dart';
import '../../data/models/family_model.dart';
import '../../data/models/family_member_model.dart';

class AuthorizationService {
  const AuthorizationService();

  /// Enforces that the current user has an active authenticated session.
  UserProfile requireAuthenticatedUser(UserProfile? user) {
    if (user == null) {
      throw const AppAuthException(
        'Authentication required to perform this action.',
        code: 'UNAUTHENTICATED',
      );
    }
    return user;
  }

  /// Enforces that the current user possesses the PARENT role.
  UserProfile requireParent(UserProfile? user) {
    final authenticated = requireAuthenticatedUser(user);
    if (authenticated.role != UserRole.parent) {
      throw const AppAuthorizationException(
        'Access restricted to Parent accounts.',
        code: 'FORBIDDEN_PARENT_REQUIRED',
      );
    }
    return authenticated;
  }

  /// Enforces that the current user possesses the CHILD role.
  UserProfile requireChild(UserProfile? user) {
    final authenticated = requireAuthenticatedUser(user);
    if (authenticated.role != UserRole.child) {
      throw const AppAuthorizationException(
        'Access restricted to Child accounts.',
        code: 'FORBIDDEN_CHILD_REQUIRED',
      );
    }
    return authenticated;
  }

  /// Enforces that the user belongs to the specified family.
  void requireFamilyMember(
      UserProfile? user, List<FamilyMember> members, String familyId) {
    final authenticated = requireAuthenticatedUser(user);
    final isMember = members
        .any((m) => m.userId == authenticated.id && m.familyId == familyId);
    if (!isMember) {
      throw const AppAuthorizationException(
        'Cross-family access denied: You are not a member of this family.',
        code: 'FORBIDDEN_CROSS_FAMILY',
      );
    }
  }

  /// Enforces that the parent is the administrator of the family.
  void requireFamilyAdmin(UserProfile? user, Family family) {
    final parent = requireParent(user);
    if (family.adminUserId != parent.id) {
      throw const AppAuthorizationException(
        'Family administrator permissions required.',
        code: 'FORBIDDEN_ADMIN_REQUIRED',
      );
    }
  }
}
