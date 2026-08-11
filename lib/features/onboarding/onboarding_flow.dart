import 'package:flutter/material.dart';

import '../../data/models/catalog_crop.dart';
import '../../data/notifications/watering_notification_service.dart';
import '../../data/user_crops_repository.dart';
import 'screens/crop_picker_step.dart';
import 'screens/crop_setup_step.dart';
import 'screens/watering_promise_step.dart';
import 'screens/welcome_step.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({
    super.key,
    required this.repository,
    required this.notifications,
  });

  final UserCropsRepository repository;
  final WateringNotificationService notifications;

  static const totalSteps = 4;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  CatalogCrop? _selectedCrop;
  DateTime? _plantedAt;
  DateTime? _lastWateredAt;

  void _goToStep(int step) => setState(() => _step = step);

  void _onCropSelected(CatalogCrop crop) {
    setState(() {
      _selectedCrop = crop;
      _plantedAt = null;
      _lastWateredAt = null;
      _step = 2;
    });
  }

  void _onSetupConfirmed(CropSetupResult result) {
    setState(() {
      _plantedAt = result.plantedAt;
      _lastWateredAt = result.lastWateredAt;
      _step = 3;
    });
  }

  VoidCallback? _onBack() {
    return switch (_step) {
      1 => () => _goToStep(0),
      2 => () => _goToStep(1),
      3 => () => _goToStep(2),
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingShell(
      currentStep: _step,
      totalSteps: OnboardingFlow.totalSteps,
      onBack: _onBack(),
      child: switch (_step) {
        0 => WelcomeStep(onNext: () => _goToStep(1)),
        1 => CropPickerStep(onCropSelected: _onCropSelected),
        2 => CropSetupStep(
            repository: widget.repository,
            crop: _selectedCrop!,
            onContinue: _onSetupConfirmed,
          ),
        3 => WateringPromiseStep(
            repository: widget.repository,
            notifications: widget.notifications,
            crop: _selectedCrop!,
            plantedAt: _plantedAt!,
            lastWateredAt: _lastWateredAt!,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
