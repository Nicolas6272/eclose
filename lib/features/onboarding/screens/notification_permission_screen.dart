import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/user_plants_repository.dart';
import '../../plants/screens/home_screen.dart';

class NotificationPermissionScreen extends StatelessWidget {
  const NotificationPermissionScreen({
    super.key,
    required this.repository,
    required this.plantName,
    required this.wateringDays,
  });

  final UserPlantsRepository repository;
  final String plantName;
  final int wateringDays;

  Future<void> _finishOnboarding(BuildContext context) async {
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.macOS) {
      await Permission.notification.request();
    }

    await repository.completeOnboarding();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(repository: repository),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: terracotta.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_outlined, size: 40, color: terracotta),
              ),
              const SizedBox(height: 28),
              Text(
                'On te rappellera d\'arroser ton $plantName dans $wateringDays jours 💧',
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Active les notifications pour ne jamais oublier.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: vertProfond.withValues(alpha: 0.7),
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _finishOnboarding(context),
                  child: const Text('Activer les rappels'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _finishOnboarding(context),
                  child: const Text('Plus tard'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
