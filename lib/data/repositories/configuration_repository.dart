import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/errors/app_exceptions.dart';
import '../models/report_config_model.dart';
import '../models/trigger_config_model.dart';
import '../models/notification_pref_model.dart';
import '../models/privacy_setting_model.dart';

abstract class ConfigurationRepository {
  Future<List<ReportConfiguration>> getReportConfigurations(String familyId);
  Future<ReportConfiguration> createReportConfiguration(
      ReportConfiguration config);
  Future<ReportConfiguration> updateReportConfiguration(
      ReportConfiguration config);
  Future<void> deleteReportConfiguration(String id);

  Future<List<TriggerConfiguration>> getTriggerConfigurations(String familyId);
  Future<TriggerConfiguration> createTriggerConfiguration(
      TriggerConfiguration config);
  Future<TriggerConfiguration> updateTriggerConfiguration(
      TriggerConfiguration config);
  Future<void> deleteTriggerConfiguration(String id);

  Future<NotificationPreference?> getNotificationPreferences(String userId);
  Future<NotificationPreference> updateNotificationPreferences(
      NotificationPreference prefs);

  Future<PrivacySetting?> getPrivacySettings(
      {required String familyId, required String userId});
  Future<PrivacySetting> updatePrivacySettings(PrivacySetting settings);
}

class SupabaseConfigurationRepository implements ConfigurationRepository {
  final SupabaseClient _client;

  SupabaseConfigurationRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<ReportConfiguration>> getReportConfigurations(
      String familyId) async {
    try {
      final response = await _client
          .from('report_configurations')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => ReportConfiguration.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Error loading report configurations: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<ReportConfiguration> createReportConfiguration(
      ReportConfiguration config) async {
    try {
      final payload = config.toJson()..remove('id');
      final response = await _client
          .from('report_configurations')
          .insert(payload)
          .select()
          .single();

      return ReportConfiguration.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Failed to create report configuration: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<ReportConfiguration> updateReportConfiguration(
      ReportConfiguration config) async {
    try {
      final payload = config.toJson()
        ..['updated_at'] = DateTime.now().toIso8601String();
      final response = await _client
          .from('report_configurations')
          .update(payload)
          .eq('id', config.id)
          .select()
          .single();

      return ReportConfiguration.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Failed to update report config: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<void> deleteReportConfiguration(String id) async {
    try {
      await _client.from('report_configurations').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Failed to delete report config: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<List<TriggerConfiguration>> getTriggerConfigurations(
      String familyId) async {
    try {
      final response = await _client
          .from('trigger_configurations')
          .select()
          .eq('family_id', familyId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((e) => TriggerConfiguration.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Error loading trigger configurations: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<TriggerConfiguration> createTriggerConfiguration(
      TriggerConfiguration config) async {
    try {
      final payload = config.toJson()..remove('id');
      final response = await _client
          .from('trigger_configurations')
          .insert(payload)
          .select()
          .single();

      return TriggerConfiguration.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Failed to create trigger configuration: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<TriggerConfiguration> updateTriggerConfiguration(
      TriggerConfiguration config) async {
    try {
      final payload = config.toJson()
        ..['updated_at'] = DateTime.now().toIso8601String();
      final response = await _client
          .from('trigger_configurations')
          .update(payload)
          .eq('id', config.id)
          .select()
          .single();

      return TriggerConfiguration.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Failed to update trigger: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<void> deleteTriggerConfiguration(String id) async {
    try {
      await _client.from('trigger_configurations').delete().eq('id', id);
    } on PostgrestException catch (e) {
      throw AppDatabaseException('Failed to delete trigger: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<NotificationPreference?> getNotificationPreferences(
      String userId) async {
    try {
      final response = await _client
          .from('notification_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return NotificationPreference.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Error loading notification preferences: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<NotificationPreference> updateNotificationPreferences(
      NotificationPreference prefs) async {
    try {
      final payload = prefs.toJson()
        ..['updated_at'] = DateTime.now().toIso8601String();
      final response = await _client
          .from('notification_preferences')
          .upsert(payload)
          .select()
          .single();

      return NotificationPreference.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Failed to save notification preferences: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<PrivacySetting?> getPrivacySettings({
    required String familyId,
    required String userId,
  }) async {
    try {
      final response = await _client
          .from('privacy_settings')
          .select()
          .eq('family_id', familyId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return PrivacySetting.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Error loading privacy settings: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }

  @override
  Future<PrivacySetting> updatePrivacySettings(PrivacySetting settings) async {
    try {
      final payload = settings.toJson()
        ..['updated_at'] = DateTime.now().toIso8601String();
      final response = await _client
          .from('privacy_settings')
          .upsert(payload)
          .select()
          .single();

      return PrivacySetting.fromJson(response);
    } on PostgrestException catch (e) {
      throw AppDatabaseException(
          'Failed to save privacy settings: ${e.message}');
    } catch (e) {
      throw AppDatabaseException('Unexpected error: $e');
    }
  }
}
