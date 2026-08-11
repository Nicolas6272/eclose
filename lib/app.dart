import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'data/notifications/watering_notification_service.dart';
import 'data/user_crops_repository.dart';
import 'features/crops/screens/home_screen.dart';
import 'features/onboarding/onboarding_flow.dart';

class EcloseApp extends StatelessWidget {
  const EcloseApp({
    super.key,
    required this.repository,
    required this.notifications,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;

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
      ),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({
    required this.repository,
    required this.notifications,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _isLoading = true;
  bool _onboardingComplete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    try {
      final isComplete = await widget.repository.isOnboardingComplete();
      if (isComplete) {
        // Recover schedules after OS kill / reboot.
        final crops = await widget.repository.getCrops();
        await widget.notifications.reschedule(crops);
      }
      if (!mounted) return;
      setState(() {
        _onboardingComplete = isComplete;
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: creme,
        body: Center(
          child: CircularProgressIndicator(color: terracotta),
        ),
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

    if (_onboardingComplete) {
      return HomeScreen(
        repository: widget.repository,
        notifications: widget.notifications,
      );
    }

    return OnboardingFlow(
      repository: widget.repository,
      notifications: widget.notifications,
    );
  }
}
