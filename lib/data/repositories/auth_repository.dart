import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/user_profile_model.dart';

abstract class AuthRepository {
  Stream<AuthState> get authStateChanges;
  User? get currentAuthUser;
  Future<UserProfile?> getCurrentUserProfile();
  Future<void> signInWithGoogle();
  Future<void> sendPhoneOtp({required String phoneNumber});
  Future<UserProfile> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
    required UserRole role,
    String? displayName,
  });
  Future<UserProfile> registerProfile({
    required String userId,
    required UserRole role,
    String? email,
    String? phoneNumber,
    String? displayName,
  });
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  User? get currentAuthUser => _client.auth.currentUser;

  @override
  Future<UserProfile?> getCurrentUserProfile() async {
    final user = currentAuthUser;
    if (user == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .limit(1);

      if (response.isEmpty) return null;
      return UserProfile.fromJson(response.first);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(e.message);
    } catch (e) {
      throw AppDatabaseException('Error loading user profile: ${e.toString()}');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'cleartime://auth-callback',
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException catch (e) {
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Failed to initiate Google Sign-In: $e');
    }
  }

  @override
  Future<void> sendPhoneOtp({required String phoneNumber}) async {
    try {
      await _client.auth.signInWithOtp(
        phone: phoneNumber,
        shouldCreateUser: true,
      );
    } on AuthException catch (e) {
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      throw AppAuthException('Failed to send verification SMS: $e');
    }
  }

  @override
  Future<UserProfile> verifyPhoneOtp({
    required String phoneNumber,
    required String token,
    required UserRole role,
    String? displayName,
  }) async {
    try {
      final authResponse = await _client.auth.verifyOTP(
        phone: phoneNumber,
        token: token,
        type: OtpType.sms,
      );

      final user = authResponse.user;
      if (user == null) {
        throw const AppAuthException(
            'Verification failed: User session not created.');
      }

      // Check if profile exists; if not, create it
      var profile = await getCurrentUserProfile();
      profile ??= await registerProfile(
        userId: user.id,
        role: role,
        phoneNumber: phoneNumber,
        displayName: displayName,
      );
      return profile;
    } on AuthException catch (e) {
      throw AppAuthException(e.message, code: e.statusCode);
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppAuthException('Failed to verify OTP code: $e');
    }
  }

  @override
  Future<UserProfile> registerProfile({
    required String userId,
    required UserRole role,
    String? email,
    String? phoneNumber,
    String? displayName,
  }) async {
    try {
      final payload = {
        'id': userId,
        'role': role.toDbString(),
        'email': email,
        'phone_number': phoneNumber,
        'display_name': displayName,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final response =
          await _client.from('profiles').upsert(payload).select().single();

      final profile = UserProfile.fromJson(response);

      // If parent, also ensure parent_profile row
      if (role == UserRole.parent) {
        await _client.from('parent_profiles').upsert({
          'user_id': userId,
          'is_active': true,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      return profile;
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Profile registration failed: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected registration error: $e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (e) {
      throw AppAuthException('Failed to sign out: $e');
    }
  }
}
