import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/auth/auth_service.dart';
import '../../../data/notifications/watering_notification_service.dart';
import '../../../data/sync/crops_sync_service.dart';
import '../../../data/user_crops_repository.dart';

enum AuthMode { signIn, signUp }

/// Email + password auth.
///
/// - [AuthMode.signUp] : last step of onboarding only (no sign-in toggle).
/// - [AuthMode.signIn] : after logout; [onCreateAccount] restarts onboarding.
class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.auth,
    required this.repository,
    required this.notifications,
    required this.sync,
    required this.onAuthenticated,
    required this.mode,
    this.embeddedInOnboarding = false,
    this.onCreateAccount,
  });

  final AuthService auth;
  final UserCropsRepository repository;
  final WateringNotificationService notifications;
  final CropsSyncService sync;
  final VoidCallback onAuthenticated;
  final AuthMode mode;
  final bool embeddedInOnboarding;

  /// When set on sign-in screen: resets local state and starts onboarding.
  final VoidCallback? onCreateAccount;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _error;

  bool get _isSignUp => widget.mode == AuthMode.signUp;

  @override
  void initState() {
    super.initState();
    if (widget.auth.isSignedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _finishAlreadySignedIn();
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _finishAlreadySignedIn() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      await widget.sync.syncAfterAuth();
      await widget.repository.completeOnboarding();
      final crops = await widget.repository.getCrops();
      await widget.notifications.reschedule(crops);
      if (!mounted) return;
      widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = AuthService.friendlyError(error);
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_isSignUp) {
        await widget.auth.signUpAndEnter(email: email, password: password);
      } else {
        await widget.auth.signIn(email: email, password: password);
      }

      if (!widget.auth.isSignedIn) {
        throw StateError(
          'Compte créé mais pas de session. Désactive « Confirm email » '
          'dans Supabase (Auth → Email), puis reconnecte-toi.',
        );
      }

      await widget.sync.syncAfterAuth();
      await widget.repository.completeOnboarding();
      final crops = await widget.repository.getCrops();
      await widget.notifications.reschedule(crops);

      if (!mounted) return;
      widget.onAuthenticated();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = AuthService.friendlyError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.embeddedInOnboarding) ...[
              const SizedBox(height: 12),
              Text(
                _isSignUp ? 'Créer un compte' : 'Connexion',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _isSignUp
                    ? 'Sauvegarde ton potager pour le retrouver sur tes appareils.'
                    : 'Reconnecte-toi pour retrouver ton potager.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: vertProfond.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: 28),
            ] else ...[
              const Spacer(flex: 1),
              Text(
                'Crée ton compte',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Obligatoire pour accéder à ton potager.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: vertProfond.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
            ],
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'toi@email.com',
              ),
              validator: (value) {
                final email = value?.trim() ?? '';
                if (email.isEmpty || !email.contains('@')) {
                  return 'Entre un email valide.';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              enabled: !_isSubmitting,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                hintText: '6 caractères minimum',
                suffixIcon: IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                final password = value ?? '';
                if (password.length < 6) {
                  return '6 caractères minimum.';
                }
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: terracotta,
                      height: 1.35,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (!widget.auth.isConfigured) ...[
              const SizedBox(height: 14),
              Text(
                'Supabase non configuré. Vérifie SUPABASE_URL et SUPABASE_ANON_KEY dans .env.local.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: terracotta,
                      height: 1.35,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.embeddedInOnboarding) const Spacer(flex: 2),
            if (!widget.embeddedInOnboarding) const SizedBox(height: 28),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isSignUp ? 'Créer mon compte' : 'Se connecter'),
            ),
            // Sign-in only: create account must restart onboarding.
            if (!_isSignUp && widget.onCreateAccount != null) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _isSubmitting ? null : widget.onCreateAccount,
                child: Text(
                  'Pas encore de compte ? Créer un compte',
                  style: TextStyle(color: vertProfond.withValues(alpha: 0.55)),
                ),
              ),
            ],
            if (!widget.embeddedInOnboarding) const SizedBox(height: 24),
            if (widget.embeddedInOnboarding) const SizedBox(height: 28),
          ],
        ),
      ),
    );

    if (widget.embeddedInOnboarding) {
      return content;
    }

    return Scaffold(
      backgroundColor: creme,
      body: SafeArea(child: content),
    );
  }
}
