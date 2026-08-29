import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../../core/security/secure_token_generator.dart';
import '../../core/constants/app_constants.dart';
import '../models/family_model.dart';
import '../models/child_profile_model.dart';
import '../models/family_invitation_model.dart';

abstract class FamilyRepository {
  Future<Family> createFamily({
    required String name,
    required String adminUserId,
  });

  Future<Family?> getFamilyForUser(String userId);

  Future<List<ChildProfile>> getChildrenForFamily(String familyId);

  Future<ChildProfile?> getChildProfileForUser(String userId);

  Future<FamilyInvitation> generateInvitation({
    required String familyId,
    required String createdBy,
  });

  Future<List<FamilyInvitation>> getActiveInvitations(String familyId);

  Future<void> revokeInvitation(String invitationId);

  Future<ChildProfile> redeemInvitation({
    required String invitationCode,
    required String childUserId,
    required String nickname,
    int? age,
    int avatarIndex = 0,
  });
}

class SupabaseFamilyRepository implements FamilyRepository {
  final SupabaseClient _client;

  SupabaseFamilyRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<Family> createFamily({
    required String name,
    required String adminUserId,
  }) async {
    final currentUid = _client.auth.currentUser?.id ?? adminUserId;

    // Fast path: Atomic database RPC
    try {
      final rpcRes = await _client.rpc(
        'create_family_hub',
        params: {'p_name': name},
      );
      if (rpcRes != null && rpcRes is Map<String, dynamic>) {
        return Family.fromJson(rpcRes);
      }
    } catch (_) {
      // Direct table fallback
    }

    final familyId = const Uuid().v4();
    final nowIso = DateTime.now().toIso8601String();

    try {
      // Step 1: Insert family record
      await _client.from('families').insert({
        'id': familyId,
        'name': name,
        'admin_user_id': currentUid,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // Step 2: Add creator as ADMIN in family_members
      await _client.from('family_members').upsert({
        'family_id': familyId,
        'user_id': currentUid,
        'role': 'ADMIN',
        'joined_at': nowIso,
      }, onConflict: 'family_id, user_id');

      // Step 3: Ensure default privacy and notification settings
      try {
        await _client.from('privacy_settings').upsert({
          'family_id': familyId,
          'user_id': currentUid,
          'anonymize_data': true,
          'local_processing_only': true,
          'data_retention_days': 30,
          'updated_at': nowIso,
        }, onConflict: 'family_id, user_id');
      } catch (_) {}

      try {
        await _client.from('notification_preferences').upsert({
          'family_id': familyId,
          'user_id': currentUid,
          'daily_summary': true,
          'instant_alerts': true,
          'quiet_hours_start': '21:00',
          'quiet_hours_end': '07:00',
          'updated_at': nowIso,
        }, onConflict: 'family_id, user_id');
      } catch (_) {}

      // Step 4: Fetch verified family object
      final familyRes = await _client
          .from('families')
          .select()
          .eq('id', familyId)
          .maybeSingle();

      if (familyRes != null) {
        return Family.fromJson(familyRes);
      }

      return Family(
        id: familyId,
        name: name,
        adminUserId: currentUid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Failed to create family: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppDatabaseException('Unexpected error creating family: $e');
    }
  }

  @override
  Future<Family?> getFamilyForUser(String userId) async {
    try {
      final membership = await _client
          .from('family_members')
          .select('family_id, families(*)')
          .eq('user_id', userId)
          .maybeSingle();

      if (membership == null || membership['families'] == null) {
        return null;
      }

      return Family.fromJson(membership['families'] as Map<String, dynamic>);
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Error loading family: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error loading family: $e');
    }
  }

  @override
  Future<List<ChildProfile>> getChildrenForFamily(String familyId) async {
    try {
      final response = await _client
          .from('child_profiles')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((json) => ChildProfile.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Error loading children: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error loading children: $e');
    }
  }

  @override
  Future<ChildProfile?> getChildProfileForUser(String userId) async {
    try {
      final response = await _client
          .from('child_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return ChildProfile.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Error loading child profile: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error loading child profile: $e');
    }
  }

  @override
  Future<FamilyInvitation> generateInvitation({
    required String familyId,
    required String createdBy,
  }) async {
    try {
      final code = SecureTokenGenerator.generateInvitationCode();
      final qrPayload = SecureTokenGenerator.generateQrPayload(
        invitationCode: code,
        familyId: familyId,
      );
      final expiresAt = DateTime.now().add(AppConstants.invitationExpiry);

      final response = await _client
          .from('family_invitations')
          .insert({
            'family_id': familyId,
            'created_by': createdBy,
            'invitation_code': code,
            'qr_payload': qrPayload,
            'expires_at': expiresAt.toIso8601String(),
            'max_uses': 1,
            'used_count': 0,
            'status': 'ACTIVE',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      return FamilyInvitation.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Failed to generate invitation: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error generating invitation: $e');
    }
  }

  @override
  Future<List<FamilyInvitation>> getActiveInvitations(String familyId) async {
    try {
      final response = await _client
          .from('family_invitations')
          .select()
          .eq('family_id', familyId)
          .eq('status', 'ACTIVE')
          .gt('expires_at', DateTime.now().toIso8601String())
          .order('created_at', ascending: false);

      return (response as List)
          .map(
              (json) => FamilyInvitation.fromJson(json as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Error loading invitations: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error loading invitations: $e');
    }
  }

  @override
  Future<void> revokeInvitation(String invitationId) async {
    try {
      await _client
          .from('family_invitations')
          .update({'status': 'REVOKED'}).eq('id', invitationId);
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Failed to revoke invitation: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error revoking invitation: $e');
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
    final cleanCode = SecureTokenGenerator.parseInvitationCode(invitationCode);

    try {
      // Try invoking the database RPC function first
      await _client.rpc(
        'redeem_family_invitation',
        params: {
          'p_invitation_code': cleanCode,
          'p_nickname': nickname,
          'p_age': age,
          'p_avatar_index': avatarIndex,
        },
      );

      final profile = await getChildProfileForUser(childUserId);
      if (profile != null) return profile;

      throw const AppInvitationException(
          'Failed to retrieve child profile after redemption.');
    } on PostgrestException catch (e) {
      if (e.message.contains('Invalid invitation') ||
          e.message.contains('expired') ||
          e.message.contains('maximum uses')) {
        throw AppInvitationException(e.message);
      }
      throw AppDatabaseException('Redemption failed: ${e.message}');
    } catch (e) {
      if (e is AppException) rethrow;
      throw AppInvitationException('Could not redeem invitation: $e');
    }
  }
}
