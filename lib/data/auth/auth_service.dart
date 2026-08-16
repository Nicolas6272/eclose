import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';

/// Thin wrapper around Supabase Auth (email + password).
class AuthService {
  AuthService({this._client});

  SupabaseClient? _client;

  SupabaseClient get client {
    final c = _client ?? Supabase.instance.client;
    return c;
  }

  bool get isConfigured => SupabaseConfig.isConfigured;

  Session? get currentSession =>
      isConfigured ? client.auth.currentSession : null;

  User? get currentUser => isConfigured ? client.auth.currentUser : null;

  bool get isSignedIn => currentSession != null;

  Stream<AuthState> get authStateChanges {
    if (!isConfigured) {
      return const Stream<AuthState>.empty();
    }
    return client.auth.onAuthStateChange;
  }

  Future<void> initialize() async {
    if (!SupabaseConfig.isConfigured) {
      return;
    }
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.anonKey,
    );
    _client = Supabase.instance.client;
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    _ensureConfigured();
    return client.auth.signUp(
      email: email.trim(),
      password: password,
    );
  }

  /// Sign up then sign in only if Supabase did not return a session (e.g. email confirm on).
  Future<void> signUpAndEnter({
    required String email,
    required String password,
  }) async {
    final response = await signUp(email: email, password: password);
    if (response.session != null || isSignedIn) return;
    await signIn(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    _ensureConfigured();
    return client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    if (!isConfigured) return;
    await client.auth.signOut();
  }

  void _ensureConfigured() {
    if (!isConfigured) {
      throw StateError(
        'Supabase n\'est pas configuré. Relance avec : '
        'flutter run --dart-define-from-file=.env',
      );
    }
  }

  /// Maps GoTrue / network errors to short French messages.
  static String friendlyError(Object error) {
    if (error is AuthException) {
      final code = error.statusCode;
      final msg = error.message.toLowerCase();
      if (code == '429' ||
          msg.contains('rate limit') ||
          msg.contains('over_email_send_rate_limit')) {
        if (msg.contains('email')) {
          return 'Limite d’emails Supabase atteinte (2/h en gratuit). '
              'Désactive « Confirm email » dans Auth → Email, ou attends 1 h.';
        }
        return 'Trop de tentatives. Attends 1 à 2 minutes, puis réessaie.';
      }
      if (code == '422' ||
          error.message.toLowerCase().contains('already registered')) {
        return 'Un compte existe déjà avec cet email. Connecte-toi.';
      }
      if (code == '400' &&
          error.message.toLowerCase().contains('invalid login credentials')) {
        return 'Email ou mot de passe incorrect.';
      }
      if (error.message.isNotEmpty) {
        return error.message;
      }
    }

    final message = error is StateError ? error.message : error.toString();
    final raw = message.toLowerCase();
    if (raw.contains('pgrst') || raw.contains('postgrest')) {
      if (raw.contains('user_crops') || raw.contains('schema cache')) {
        return 'Table user_crops introuvable. Applique la migration Supabase.';
      }
      return 'Erreur base de données. Réessaie.';
    }
    if (raw.contains('429') || raw.contains('rate limit')) {
      return 'Trop de tentatives. Attends 1 à 2 minutes, puis réessaie.';
    }
    if (raw.contains('invalid login credentials') ||
        raw.contains('invalid_credentials')) {
      return 'Email ou mot de passe incorrect.';
    }
    if (raw.contains('user already registered') ||
        raw.contains('already been registered')) {
      return 'Un compte existe déjà avec cet email. Connecte-toi.';
    }
    if (raw.contains('password should be at least')) {
      return 'Mot de passe trop court (6 caractères minimum).';
    }
    if (raw.contains('email') && raw.contains('invalid')) {
      return 'Adresse email invalide.';
    }
    if (raw.contains('network') || raw.contains('socket')) {
      return 'Réseau indisponible. Réessaie plus tard.';
    }
    if (raw.contains('supabase n\'est pas configuré')) {
      return 'Supabase non configuré. Utilise --dart-define-from-file=.env';
    }
    return 'Connexion impossible. Réessaie.';
  }
}
