import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/crop_catalog.dart';
import '../../../data/models/user_crop.dart';
import 'crop_avatar.dart';

class CropCard extends StatelessWidget {
  const CropCard({
    super.key,
    required this.crop,
    this.onWater,
    this.showWaterAlways = true,
  });

  final UserCrop crop;
  final VoidCallback? onWater;
  final bool showWaterAlways;

  @override
  Widget build(BuildContext context) {
    final catalog = CropCatalog.byId(crop.catalogCropId);
    final daysLeft = catalog == null ? 0 : crop.daysUntilWatering(catalog);
    final due = catalog != null && crop.isDue(catalog);

    String subtitle;
    if (catalog == null) {
      subtitle = 'Culture inconnue';
    } else if (due) {
      subtitle = daysLeft < 0
          ? 'En retard de ${-daysLeft} jour${-daysLeft > 1 ? 's' : ''}'
          : 'À arroser aujourd\'hui';
    } else {
      subtitle =
          'Prochain arrosage dans $daysLeft jour${daysLeft > 1 ? 's' : ''}';
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (catalog != null)
              CropAvatar(crop: catalog, size: 48)
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
                  Text(
                    crop.displayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: due
                              ? terracotta
                              : vertProfond.withValues(alpha: 0.6),
                          fontWeight:
                              due ? FontWeight.w600 : FontWeight.normal,
                        ),
                  ),
                ],
              ),
            ),
            if (onWater != null && (showWaterAlways || due))
              FilledButton(
                onPressed: onWater,
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Arrosé'),
              ),
          ],
        ),
      ),
    );
  }
}
