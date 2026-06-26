import 'package:flutter/material.dart';

import '../../../data/models/catalog_plant.dart';
import '../../../data/user_plants_repository.dart';
import '../../onboarding/screens/last_watered_step.dart';

class LastWateredScreen extends StatelessWidget {
  const LastWateredScreen({
    super.key,
    required this.repository,
    required this.plant,
  });

  final UserPlantsRepository repository;
  final CatalogPlant plant;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dernier arrosage'),
      ),
      body: SafeArea(
        child: LastWateredStep(
          repository: repository,
          plant: plant,
          isOnboarding: false,
          onContinue: (_) => Navigator.of(context).pop(true),
        ),
      ),
    );
  }
}
