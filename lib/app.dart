import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'data/auth/auth_service.dart';
import 'data/notifications/watering_notification_service.dart';
import 'data/user_crops_repository.dart';
import 'features/auth/screens/auth_screen.dart';
import 'features/crops/screens/home_screen.dart';
import 'features/onboarding/onboarding_flow.dart';

class EcloseApp extends StatelessWidget {
  const EcloseApp({
    super.key,
    required this.repository,
    required this.notifications,
    required this.auth,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Éclose',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _AppEntry(
        repository: repository,
        notifications: notifications,
        auth: auth,
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({
    required this.repository,
    required this.notifications,
    required this.auth,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;
  final AuthService auth;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _isLoading = true;
  bool _deviceOnboarded = false;
  bool _forceOnboarding = false;
  bool _hasSession = false;
  String? _error;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _bootstrap();
    _authSub = widget.auth.authStateChanges.listen((state) {
      if (!mounted) return;
      setState(() => _hasSession = state.session != null);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final deviceOnboarded = await widget.repository.hasDeviceOnboarded();
      final hasSession = widget.auth.isSignedIn;

      // Quit mid-onboarding → restart clean (no leftover draft).
      if (!hasSession) {
        await widget.repository.clearOnboardingDraft();
      }

      if (hasSession) {
        try {
          final crops = await widget.repository.getCrops();
          await widget.notifications.reschedule(crops);
        } catch (_) {
          // Table missing / offline: still open Home.
        }
      }

      if (!mounted) return;
      setState(() {
        _deviceOnboarded = deviceOnboarded;
        _hasSession = hasSession;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _onAuthSuccess() async {
    await widget.repository.markDeviceOnboarded();
    if (!mounted) return;
    setState(() {
      _deviceOnboarded = true;
      _forceOnboarding = false;
      _hasSession = true;
    });
  }

  Future<void> _onSignedOut() async {
    await widget.notifications.cancelAll();
    if (!mounted) return;
    setState(() {
      _hasSession = false;
      _forceOnboarding = false;
    });
  }

  Future<void> _startCreateAccount() async {
    await widget.repository.clearOnboardingDraft();
    if (!mounted) return;
    setState(() {
      _forceOnboarding = true;
      _hasSession = false;
    });
  }

  void _cancelCreateAccount() {
    setState(() => _forceOnboarding = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: creme,
        body: Center(child: CircularProgressIndicator(color: terracotta)),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: creme,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Erreur au démarrage :\n$_error',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      );
    }

    if (_hasSession) {
      return HomeScreen(
        repository: widget.repository,
        notifications: widget.notifications,
        auth: widget.auth,
        onSignedOut: _onSignedOut,
      );
    }

    if (_deviceOnboarded && !_forceOnboarding) {
      return AuthScreen(
        auth: widget.auth,
        repository: widget.repository,
        notifications: widget.notifications,
        mode: AuthMode.signIn,
        onAuthenticated: _onAuthSuccess,
        onCreateAccount: _startCreateAccount,
      );
    }

    return OnboardingFlow(
      repository: widget.repository,
      notifications: widget.notifications,
      auth: widget.auth,
      onAuthenticated: _onAuthSuccess,
      onCancelToLogin: _deviceOnboarded ? _cancelCreateAccount : null,
    );
  }
}
