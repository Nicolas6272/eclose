import 'package:flutter/material.dart';

import '../../data/models/catalog_plant.dart';
import '../../data/user_plants_repository.dart';
import 'screens/last_watered_step.dart';
import 'screens/plant_picker_step.dart';
import 'screens/watering_promise_step.dart';
import 'screens/welcome_step.dart';
import 'widgets/onboarding_shell.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key, required this.repository});

  final UserPlantsRepository repository;

  static const totalSteps = 4;

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  int _step = 0;
  CatalogPlant? _selectedPlant;
  DateTime? _lastWateredAt;

  void _goToStep(int step) => setState(() => _step = step);

  void _onPlantSelected(CatalogPlant plant) {
    setState(() {
      _selectedPlant = plant;
      _lastWateredAt = null;
      _step = 2;
    });
  }

  void _onLastWateredConfirmed(DateTime lastWateredAt) {
    setState(() {
      _lastWateredAt = lastWateredAt;
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
        1 => PlantPickerStep(onPlantSelected: _onPlantSelected),
        2 => LastWateredStep(
            repository: widget.repository,
            plant: _selectedPlant!,
            onContinue: _onLastWateredConfirmed,
          ),
        3 => WateringPromiseStep(
            repository: widget.repository,
            plant: _selectedPlant!,
            lastWateredAt: _lastWateredAt!,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
