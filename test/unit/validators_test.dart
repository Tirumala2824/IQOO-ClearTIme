import 'package:flutter_test/flutter_test.dart';
import 'package:cleartime/core/utils/validators.dart';

void main() {
  group('Validators Unit Tests', () {
    test('validatePhoneNumber handles valid and invalid inputs', () {
      expect(Validators.validatePhoneNumber('+1234567890'), isNull);
      expect(Validators.validatePhoneNumber('+447911123456'), isNull);
      expect(Validators.validatePhoneNumber(''), isNotNull);
      expect(Validators.validatePhoneNumber('abc'), isNotNull);
      expect(Validators.validatePhoneNumber('123'), isNotNull);
    });

    test('validateOtp validates 6-digit codes', () {
      expect(Validators.validateOtp('123456'), isNull);
      expect(Validators.validateOtp('987654'), isNull);
      expect(Validators.validateOtp('12345'), isNotNull);
      expect(Validators.validateOtp('1234567'), isNotNull);
      expect(Validators.validateOtp('12345a'), isNotNull);
      expect(Validators.validateOtp(''), isNotNull);
    });

    test('validateFamilyName enforces length bounds', () {
      expect(Validators.validateFamilyName('The Smiths'), isNull);
      expect(Validators.validateFamilyName('M'), isNotNull);
      expect(Validators.validateFamilyName(''), isNotNull);
      expect(Validators.validateFamilyName('A' * 55), isNotNull);
    });

    test('validateChildNickname enforces valid nicknames', () {
      expect(Validators.validateChildNickname('Leo'), isNull);
      expect(Validators.validateChildNickname('A'), isNotNull);
      expect(Validators.validateChildNickname(''), isNotNull);
    });

    test('validateChildAge validates realistic ages', () {
      expect(Validators.validateChildAge(null), isNull); // Optional
      expect(Validators.validateChildAge(''), isNull); // Optional
      expect(Validators.validateChildAge('10'), isNull);
      expect(Validators.validateChildAge('25'), isNotNull);
      expect(Validators.validateChildAge('-5'), isNotNull);
    });

    test('validateInvitationCode enforces 8 uppercase alphanumeric chars', () {
      expect(Validators.validateInvitationCode('7X9K2M4P'), isNull);
      expect(Validators.validateInvitationCode('ABCDEFGH'), isNull);
      expect(Validators.validateInvitationCode('1234567'), isNotNull);
      expect(Validators.validateInvitationCode('123456789'), isNotNull);
      expect(Validators.validateInvitationCode(''), isNotNull);
    });

    test('validateThresholdMinutes enforces bounds', () {
      expect(Validators.validateThresholdMinutes('60'), isNull);
      expect(Validators.validateThresholdMinutes('120'), isNull);
      expect(Validators.validateThresholdMinutes('2'), isNotNull);
      expect(Validators.validateThresholdMinutes('2000'), isNotNull);
      expect(Validators.validateThresholdMinutes(''), isNotNull);
    });
  });
}
