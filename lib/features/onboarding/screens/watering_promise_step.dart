import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../data/models/catalog_crop.dart';
import '../../../data/models/user_crop.dart';
import '../../../data/notifications/watering_notification_service.dart';
import '../../../data/user_crops_repository.dart';
import '../widgets/plant_added_badge.dart';

class WateringPromiseStep extends StatefulWidget {
  const WateringPromiseStep({
    super.key,
    required this.repository,
    required this.notifications,
    required this.crop,
    required this.plantedAt,
    required this.lastWateredAt,
    required this.onContinue,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;
  final CatalogCrop crop;
  final DateTime plantedAt;
  final DateTime lastWateredAt;
  final VoidCallback onContinue;

  @override
  State<WateringPromiseStep> createState() => _WateringPromiseStepState();
}

class _WateringPromiseStepState extends State<WateringPromiseStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;
  bool _isFinishing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _contentOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.85, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _nextWateringHeadline(UserCrop preview) {
    final due = preview.isDue(widget.crop);
    final days = preview.daysUntilWatering(widget.crop);
    final next = preview.nextWateringAt(widget.crop);

    if (due) return 'À arroser dès aujourd\'hui';
    if (days == 1) return 'Prochain arrosage demain';
    return 'Prochain arrosage le ${formatFrenchDate(next)}';
  }

  Future<void> _finish({required bool requestNotifications}) async {
    if (_isFinishing) return;
    setState(() => _isFinishing = true);

    if (requestNotifications &&
        !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      // Soft-ask already accepted: only now fire the one-shot OS prompt.
      await widget.notifications.requestPermission();
    }

    // Crop is already saved in setup; auth step completes onboarding.
    if (!mounted) return;
    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    final preview = UserCrop.fromCatalog(
      id: 'preview',
      catalog: widget.crop,
      plantedAt: widget.plantedAt,
      lastWateredAt: widget.lastWateredAt,
    );
    final headline = _nextWateringHeadline(preview);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          const Center(child: PlantAddedBadge()),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _contentOpacity,
            child: SlideTransition(
              position: _contentSlide,
              child: Column(
                children: [
                  Text(
                    widget.crop.savedConfirmation,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 24,
                          height: 1.3,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    headline,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: 22,
                          height: 1.3,
                          color: terracotta,
                          fontWeight: FontWeight.w700,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // Soft-ask: explain value before the one-shot OS prompt.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: sauge.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: sauge.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: sauge,
                          size: 28,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'On te dira quoi arroser demain matin — un seul rappel groupé.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontSize: 16,
                                    height: 1.45,
                                    color: vertProfond.withValues(alpha: 0.75),
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 3),
          FilledButton(
            onPressed: _isFinishing
                ? null
                : () => _finish(requestNotifications: true),
            child: _isFinishing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Activer les notifications'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _isFinishing
                ? null
                : () => _finish(requestNotifications: false),
            child: Text(
              'Continuer sans notifications',
              style: TextStyle(color: vertProfond.withValues(alpha: 0.45)),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
