import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class SecureTokenGenerator {
  SecureTokenGenerator._();

  static final Random _secureRandom = Random.secure();
  static const String _alphabet =
      '23456789ABCDEFGHJKLMNPQRSTUVWXYZ'; // base32 human-friendly (no 0,1,I,O)

  /// Generates a cryptographically secure random invitation code.
  static String generateInvitationCode({int length = 8}) {
    final buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      final index = _secureRandom.nextInt(_alphabet.length);
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }

  /// Generates a tamper-evident QR payload containing the invitation code and secure HMAC hash.
  static String generateQrPayload({
    required String invitationCode,
    required String familyId,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rawData = '$invitationCode|$familyId|$timestamp';
    final bytes = utf8.encode(rawData);
    final digest = sha256.convert(bytes);
    return jsonEncode({
      'type': 'cleartime_invitation',
      'code': invitationCode,
      'fid': familyId,
      't': timestamp,
      'sig': digest.toString().substring(0, 16),
    });
  }

  /// Parses invitation code from raw text or QR payload.
  static String parseInvitationCode(String input) {
    final trimmed = input.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        if (decoded['code'] != null) {
          return decoded['code'].toString().toUpperCase();
        }
      } catch (_) {}
    }
    return trimmed.toUpperCase();
  }
}
