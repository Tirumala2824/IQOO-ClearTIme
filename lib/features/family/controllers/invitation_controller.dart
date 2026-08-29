import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/family_invitation_model.dart';
import '../../../data/models/child_profile_model.dart';
import '../../../data/repositories/family_repository.dart';

class InvitationState {
  final FamilyInvitation? latestInvitation;
  final List<FamilyInvitation> activeInvitations;
  final bool isLoading;
  final String? errorMessage;
  final bool isRedeemed;

  const InvitationState({
    this.latestInvitation,
    this.activeInvitations = const [],
    this.isLoading = false,
    this.errorMessage,
    this.isRedeemed = false,
  });

  InvitationState copyWith({
    FamilyInvitation? latestInvitation,
    List<FamilyInvitation>? activeInvitations,
    bool? isLoading,
    String? errorMessage,
    bool? isRedeemed,
    bool clearLatest = false,
    bool clearError = false,
  }) {
    return InvitationState(
      latestInvitation:
          clearLatest ? null : (latestInvitation ?? this.latestInvitation),
      activeInvitations: activeInvitations ?? this.activeInvitations,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isRedeemed: isRedeemed ?? this.isRedeemed,
    );
  }
}

class InvitationController extends StateNotifier<InvitationState> {
  final FamilyRepository _familyRepository;

  InvitationController(this._familyRepository) : super(const InvitationState());

  Future<void> loadActiveInvitations(String familyId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final invitations =
          await _familyRepository.getActiveInvitations(familyId);
      state = state.copyWith(
        activeInvitations: invitations,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<FamilyInvitation?> generateInvitation({
    required String familyId,
    required String parentUserId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final invitation = await _familyRepository.generateInvitation(
        familyId: familyId,
        createdBy: parentUserId,
      );
      state = state.copyWith(
        latestInvitation: invitation,
        activeInvitations: [invitation, ...state.activeInvitations],
        isLoading: false,
      );
      return invitation;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<void> revokeInvitation(String invitationId, String familyId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _familyRepository.revokeInvitation(invitationId);
      await loadActiveInvitations(familyId);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<ChildProfile?> redeemInvitation({
    required String invitationCode,
    required String childUserId,
    required String nickname,
    int? age,
    int avatarIndex = 0,
  }) async {
    state =
        state.copyWith(isLoading: true, clearError: true, isRedeemed: false);
    try {
      final profile = await _familyRepository.redeemInvitation(
        invitationCode: invitationCode,
        childUserId: childUserId,
        nickname: nickname,
        age: age,
        avatarIndex: avatarIndex,
      );
      state = state.copyWith(isLoading: false, isRedeemed: true);
      return profile;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }
}

final invitationControllerProvider =
    StateNotifierProvider<InvitationController, InvitationState>((ref) {
  final repository = ref.watch(familyRepositoryProvider);
  return InvitationController(repository);
});
