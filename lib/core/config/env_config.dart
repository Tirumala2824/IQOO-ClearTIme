import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client environment configuration.
///
/// CRITICAL SECURITY RULE:
/// Only [supabaseUrl] and [supabasePublishableKey] may be accessed by the Flutter client.
/// Server secret keys, DATABASE_URL, and DIRECT_URL are strictly forbidden inside the mobile application.
class EnvConfig {
  EnvConfig._();

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fallback if .env is missing during test execution
    }
  }

  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? '';
  }

  static String get supabasePublishableKey {
    return dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? '';
  }

  static bool get isConfigured {
    final url = supabaseUrl;
    final key = supabasePublishableKey;
    return url.isNotEmpty && key.isNotEmpty;
  }

  /// FCM push delivery stays off until Firebase credentials are provisioned.
  static bool get enableFcm =>
      dotenv.env['ENABLE_FCM'] == 'true' &&
      dotenv.env['FIREBASE_PROJECT_ID'] != null &&
      dotenv.env['FIREBASE_PROJECT_ID']!.isNotEmpty;
}
