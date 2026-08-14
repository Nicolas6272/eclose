import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase keys loaded from `.env.local` (bundled as asset, gitignored).
abstract final class SupabaseConfig {
  static String get url => dotenv.get('SUPABASE_URL', fallback: '');
  static String get anonKey => dotenv.get('SUPABASE_ANON_KEY', fallback: '');

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
