import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Client environment configuration.
///
/// CRITICAL SECURITY RULE:
/// Only [supabaseUrl] and [supabasePublishableKey] may be accessed by the Flutter client.
/// Server secret keys, DATABASE_URL, and DIRECT_URL are strictly forbidden inside the mobile application.
class EnvConfig {
  EnvConfig._();

  static const String _defaultSupabaseUrl = 'https://demo.supabase.co';
  static const String _defaultPublishableKey = 'sb_pub_placeholder';

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (_) {
      // Fallback if .env is missing during test execution
    }
  }

  static String get supabaseUrl {
    return dotenv.env['SUPABASE_URL'] ?? _defaultSupabaseUrl;
  }

  static String get supabasePublishableKey {
    return dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ?? _defaultPublishableKey;
  }

  static bool get isConfigured {
    final url = supabaseUrl;
    final key = supabasePublishableKey;
    return url.isNotEmpty &&
        url != _defaultSupabaseUrl &&
        key.isNotEmpty &&
        key != _defaultPublishableKey;
  }
}
