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
    try {
      // 1. Create family
      final familyRes = await _client
          .from('families')
          .insert({
            'name': name,
            'admin_user_id': adminUserId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final family = Family.fromJson(familyRes);

      // 2. Add creator as ADMIN in family_members
      await _client.from('family_members').insert({
        'family_id': family.id,
        'user_id': adminUserId,
        'role': 'ADMIN',
        'joined_at': DateTime.now().toIso8601String(),
      });

      // 3. Ensure default privacy and notification settings
      await _client.from('privacy_settings').upsert({
        'family_id': family.id,
        'user_id': adminUserId,
        'anonymize_data': true,
        'local_processing_only': true,
        'data_retention_days': 30,
        'updated_at': DateTime.now().toIso8601String(),
      });

      await _client.from('notification_preferences').upsert({
        'family_id': family.id,
        'user_id': adminUserId,
        'daily_summary': true,
        'instant_alerts': true,
        'quiet_hours_start': '21:00',
        'quiet_hours_end': '07:00',
        'updated_at': DateTime.now().toIso8601String(),
      });

      return family;
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Failed to create family: ${e.message}');
    } catch (e) {
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
