import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/providers.dart';
import '../../../data/models/user_profile_model.dart';
import '../../../data/repositories/auth_repository.dart';

class AuthState {
  final UserProfile? user;
  final bool isLoading;
  final String? errorMessage;
  final String? pendingPhone;
  final UserRole selectedRole;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
    this.pendingPhone,
    this.selectedRole = UserRole.parent,
  });

  bool get isAuthenticated => user != null;
  bool get isParent => user?.isParent ?? (selectedRole == UserRole.parent);
  bool get isChild => user?.isChild ?? (selectedRole == UserRole.child);

  AuthState copyWith({
    UserProfile? user,
    bool? isLoading,
    String? errorMessage,
    String? pendingPhone,
    UserRole? selectedRole,
    bool clearUser = false,
    bool clearError = false,
    bool clearPendingPhone = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      pendingPhone:
          clearPendingPhone ? null : (pendingPhone ?? this.pendingPhone),
      selectedRole: selectedRole ?? this.selectedRole,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthController(this._authRepository) : super(const AuthState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _authRepository.getCurrentUserProfile();
      state = state.copyWith(user: profile, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void setSelectedRole(UserRole role) {
    state = state.copyWith(selectedRole: role);
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.signInWithGoogle();
      // Google redirects back via deep-link
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> sendPhoneOtp(String phoneNumber) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _authRepository.sendPhoneOtp(phoneNumber: phoneNumber);
      state = state.copyWith(
        isLoading: false,
        pendingPhone: phoneNumber,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp({
    required String token,
    String? displayName,
  }) async {
    final phone = state.pendingPhone;
    if (phone == null) {
      state =
          state.copyWith(errorMessage: 'No pending phone verification found.');
      return false;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final profile = await _authRepository.verifyPhoneOtp(
        phoneNumber: phone,
        token: token,
        role: state.selectedRole,
        displayName: displayName,
      );
      state = state.copyWith(
        user: profile,
        isLoading: false,
        clearPendingPhone: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> setUserProfile(UserProfile profile) async {
    state = state.copyWith(user: profile);
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      await _authRepository.signOut();
      state = const AuthState();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final repository = ref.watch(authRepositoryProvider);
  return AuthController(repository);
});
