import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/security/secure_token_generator.dart';

void main() {
  group('SecureTokenGenerator Unit Tests', () {
    test(
        'generateInvitationCode produces 8-character uppercase alphanumeric code',
        () {
      final code1 = SecureTokenGenerator.generateInvitationCode();
      final code2 = SecureTokenGenerator.generateInvitationCode();

      expect(code1.length, equals(8));
      expect(code2.length, equals(8));
      expect(code1, isNot(equals(code2)));
      expect(RegExp(r'^[2-9A-HJ-NP-Z]{8}$').hasMatch(code1), isTrue);
    });

    test('generateQrPayload creates valid JSON payload with signature', () {
      final payload = SecureTokenGenerator.generateQrPayload(
        invitationCode: '7X9K2M4P',
        familyId: 'family-uuid-123',
      );

      expect(payload, contains('cleartime_invitation'));
      expect(payload, contains('7X9K2M4P'));
      expect(payload, contains('family-uuid-123'));
      expect(payload, contains('sig'));
    });

    test(
        'parseInvitationCode extracts code from raw string and QR json payload',
        () {
      expect(SecureTokenGenerator.parseInvitationCode('7x9k2m4p'),
          equals('7X9K2M4P'));

      final qrJson =
          '{"type":"cleartime_invitation","code":"8M2P4Q7W","fid":"123"}';
      expect(
          SecureTokenGenerator.parseInvitationCode(qrJson), equals('8M2P4Q7W'));
    });
  });
}
