import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase keys: `--dart-define` wins, then values loaded from `.env` (file, not asset).
abstract final class SupabaseConfig {
  static const _defineUrl = String.fromEnvironment('SUPABASE_URL');
  static const _defineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static String _fromDotenv(String key) {
    try {
      return dotenv.maybeGet(key) ?? '';
    } catch (_) {
      // DotEnv not loaded yet (tests / early boot).
      return '';
    }
  }

  static String get url {
    if (_defineUrl.isNotEmpty) return _defineUrl;
    return _fromDotenv('SUPABASE_URL');
  }

  static String get anonKey {
    if (_defineAnonKey.isNotEmpty) return _defineAnonKey;
    return _fromDotenv('SUPABASE_ANON_KEY');
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
