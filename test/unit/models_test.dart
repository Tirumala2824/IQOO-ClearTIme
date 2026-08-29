import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/data/models/user_profile_model.dart';
import 'package:cleartime/data/models/child_profile_model.dart';
import 'package:cleartime/data/models/family_model.dart';
import 'package:cleartime/data/models/family_invitation_model.dart';
import 'package:cleartime/data/models/report_config_model.dart';
import 'package:cleartime/data/models/trigger_config_model.dart';
import 'package:cleartime/data/models/notification_pref_model.dart';
import 'package:cleartime/data/models/privacy_setting_model.dart';

void main() {
  group('Data Models Unit Tests', () {
    test('UserProfile JSON serialization and deserialization', () {
      final json = {
        'id': 'u1',
        'email': 'parent@example.com',
        'phone_number': '+1234567890',
        'role': 'PARENT',
        'display_name': 'Sarah',
        'avatar_url': null,
        'created_at': '2026-08-29T10:00:00.000Z',
        'updated_at': '2026-08-29T10:00:00.000Z',
      };

      final profile = UserProfile.fromJson(json);
      expect(profile.id, equals('u1'));
      expect(profile.isParent, isTrue);
      expect(profile.isChild, isFalse);
      expect(profile.displayName, equals('Sarah'));

      final outJson = profile.toJson();
      expect(outJson['role'], equals('PARENT'));
    });

    test('ChildProfile JSON serialization and deserialization', () {
      final json = {
        'id': 'c1',
        'user_id': 'u2',
        'family_id': 'f1',
        'nickname': 'Tommy',
        'age': 10,
        'avatar_index': 2,
        'created_at': '2026-08-29T10:00:00.000Z',
        'updated_at': '2026-08-29T10:00:00.000Z',
      };

      final child = ChildProfile.fromJson(json);
      expect(child.nickname, equals('Tommy'));
      expect(child.age, equals(10));
      expect(child.avatarIndex, equals(2));
    });

    test('Family JSON serialization and deserialization', () {
      final json = {
        'id': 'f1',
        'name': 'The Harrison Family',
        'admin_user_id': 'u1',
        'created_at': '2026-08-29T10:00:00.000Z',
        'updated_at': '2026-08-29T10:00:00.000Z',
      };

      final family = Family.fromJson(json);
      expect(family.name, equals('The Harrison Family'));
      expect(family.adminUserId, equals('u1'));
      expect(family.toJson()['name'], equals('The Harrison Family'));
    });

    test('FamilyInvitation validation logic', () {
      final activeInvite = FamilyInvitation(
        id: 'inv1',
        familyId: 'f1',
        createdBy: 'u1',
        invitationCode: '7X9K2M4P',
        qrPayload: 'qr_test',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        maxUses: 1,
        usedCount: 0,
        status: InvitationStatus.active,
        createdAt: DateTime.now(),
      );
      expect(activeInvite.isValid, isTrue);

      final expiredInvite = FamilyInvitation(
        id: 'inv2',
        familyId: 'f1',
        createdBy: 'u1',
        invitationCode: '7X9K2M4P',
        qrPayload: 'qr_test',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        maxUses: 1,
        usedCount: 0,
        status: InvitationStatus.active,
        createdAt: DateTime.now(),
      );
      expect(expiredInvite.isValid, isFalse);

      final usedInvite = FamilyInvitation(
        id: 'inv3',
        familyId: 'f1',
        createdBy: 'u1',
        invitationCode: '7X9K2M4P',
        qrPayload: 'qr_test',
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        maxUses: 1,
        usedCount: 1,
        status: InvitationStatus.used,
        createdAt: DateTime.now(),
      );
      expect(usedInvite.isValid, isFalse);
    });

    test('ReportConfiguration serialization', () {
      final config = ReportConfiguration(
        id: 'r1',
        familyId: 'f1',
        createdBy: 'u1',
        title: 'Weekly Summary',
        frequency: ReportFrequency.weekly,
        deliveryChannel: DeliveryChannel.inApp,
        isEnabled: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = config.toJson();
      expect(json['frequency'], equals('WEEKLY'));
      expect(json['delivery_channel'], equals('IN_APP'));
    });

    test('TriggerConfiguration serialization', () {
      final trigger = TriggerConfiguration(
        id: 't1',
        familyId: 'f1',
        childId: 'c1',
        type: TriggerType.usageIncrease,
        threshold: 20.0,
        enabled: true,
        cooldown: const Duration(hours: 24),
        notificationType: NotificationType.push,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final json = trigger.toJson();
      expect(json['threshold'], equals(20.0));
      expect(json['type'], equals('usageIncrease'));
      expect(json['cooldown_seconds'], equals(86400));
    });

    test('PrivacySetting serialization', () {
      final setting = PrivacySetting(
        id: 'p1',
        familyId: 'f1',
        userId: 'u1',
        anonymizeData: true,
        localProcessingOnly: true,
        dataRetentionDays: 30,
        updatedAt: DateTime.now(),
      );

      final json = setting.toJson();
      expect(json['local_processing_only'], isTrue);
      expect(json['data_retention_days'], equals(30));
    });

    test('NotificationPreference serialization', () {
      final notif = NotificationPreference(
        id: 'n1',
        userId: 'u1',
        familyId: 'f1',
        dailySummary: true,
        instantAlerts: true,
        quietHoursStart: '21:00',
        quietHoursEnd: '07:00',
        updatedAt: DateTime.now(),
      );

      final json = notif.toJson();
      expect(json['quiet_hours_start'], equals('21:00'));
      expect(json['daily_summary'], isTrue);
    });
  });
}
