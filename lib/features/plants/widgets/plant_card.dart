import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/user_plant.dart';
import '../../../data/plants_catalog.dart';
import 'plant_avatar.dart';

class PlantCard extends StatelessWidget {
  const PlantCard({
    super.key,
    required this.plant,
    this.onWater,
  });

  final UserPlant plant;
  final VoidCallback? onWater;

  bool get _isDueToday => plant.daysUntilWatering == 0;

  @override
  Widget build(BuildContext context) {
    final daysLeft = plant.daysUntilWatering;
    final catalogPlant = catalogPlantById(plant.catalogPlantId);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (catalogPlant != null)
              PlantAvatar(plant: catalogPlant, size: 48)
            else
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: sauge.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco_outlined, color: sauge),
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plant.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _isDueToday
                        ? 'À arroser aujourd\'hui'
                        : 'Prochain arrosage dans $daysLeft jour${daysLeft > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _isDueToday ? terracotta : vertProfond.withValues(alpha: 0.6),
                          fontWeight: _isDueToday ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
            if (_isDueToday && onWater != null)
              FilledButton(
                onPressed: onWater,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                child: const Text('Arroser'),
              ),
          ],
        ),
      ),
    );
  }
}
