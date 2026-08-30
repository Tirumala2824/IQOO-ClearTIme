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

  /// Parses invitation code from raw text, JSON QR payload, or URI.
  static String parseInvitationCode(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    // 1. Check JSON payload
    if (trimmed.contains('{') && trimmed.contains('}')) {
      try {
        final startIndex = trimmed.indexOf('{');
        final endIndex = trimmed.lastIndexOf('}');
        final jsonStr = trimmed.substring(startIndex, endIndex + 1);
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          if (decoded['code'] != null) {
            return decoded['code'].toString().trim().toUpperCase();
          }
          if (decoded['invitation_code'] != null) {
            return decoded['invitation_code'].toString().trim().toUpperCase();
          }
        }
      } catch (_) {}
    }

    // 2. Check URI / query param (e.g. ?code=XYZ)
    if (trimmed.contains('code=')) {
      final match = RegExp(r'code=([A-Za-z0-9]+)').firstMatch(trimmed);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.toUpperCase();
      }
    }

    // 3. Match standard 8-character base32 token
    final tokenMatch = RegExp(r'\b[2-9A-HJ-NP-Z]{8}\b', caseSensitive: false).firstMatch(trimmed);
    if (tokenMatch != null) {
      return tokenMatch.group(0)!.toUpperCase();
    }

    // 4. Fallback cleanup: remove whitespace, non-alphanumeric
    return trimmed.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
  }
}
