import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_plant.dart';
import '../../../data/models/user_plant.dart';
import '../../../data/user_plants_repository.dart';
import '../widgets/plant_added_badge.dart';
import '../widgets/watering_timeline.dart';
import '../../plants/screens/home_screen.dart';

class WateringPromiseStep extends StatefulWidget {
  const WateringPromiseStep({
    super.key,
    required this.repository,
    required this.plant,
    required this.lastWateredAt,
  });

  final UserPlantsRepository repository;
  final CatalogPlant plant;
  final DateTime lastWateredAt;

  @override
  State<WateringPromiseStep> createState() => _WateringPromiseStepState();
}

class _WateringPromiseStepState extends State<WateringPromiseStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;
  late final Animation<double> _timelineProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _contentOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    _timelineProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(BuildContext context, {required bool requestNotifications}) async {
    if (requestNotifications &&
        !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      await Permission.notification.request();
    }

    await widget.repository.completeOnboarding();

    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => HomeScreen(repository: widget.repository),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plantName = widget.plant.commonName;
    final previewPlant = UserPlant.fromCatalog(
      id: 'preview',
      catalogPlantId: widget.plant.id,
      name: widget.plant.commonName,
      wateringDays: widget.plant.wateringDays,
      lastWateredAt: widget.lastWateredAt,
    );
    final daysUntilWatering = previewPlant.daysUntilWatering;
    final nextWateringDate = previewPlant.nextWateringAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          const Center(child: PlantAddedBadge()),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _contentOpacity,
            child: SlideTransition(
              position: _contentSlide,
              child: Text(
                'Ton $plantName a bien été ajouté.',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      height: 1.3,
                    ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: _contentOpacity,
            child: AnimatedBuilder(
              animation: _timelineProgress,
              builder: (context, _) => WateringTimeline(
                daysUntilWatering: daysUntilWatering,
                nextWateringDate: nextWateringDate,
                progress: _timelineProgress.value,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FadeTransition(
            opacity: _contentOpacity,
            child: Text(
            'Pour qu\'on puisse te rappeler de l\'arroser, pense à activer les notifications.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontSize: 17,
                  height: 1.55,
                  color: vertProfond.withValues(alpha: 0.6),
                ),
            textAlign: TextAlign.center,
            ),
          ),
          const Spacer(flex: 3),
          FilledButton(
            onPressed: () => _finish(context, requestNotifications: true),
            child: const Text('Activer les notifications'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => _finish(context, requestNotifications: false),
            child: Text(
              'Plus tard',
              style: TextStyle(color: vertProfond.withValues(alpha: 0.45)),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
