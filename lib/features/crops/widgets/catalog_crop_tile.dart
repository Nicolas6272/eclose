import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_crop.dart';
import 'crop_avatar.dart';

/// Shared list tile for catalog crop search (onboarding + add plant).
class CatalogCropTile extends StatelessWidget {
  const CatalogCropTile({
    super.key,
    required this.crop,
    required this.onTap,
  });

  final CatalogCrop crop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              CropAvatar(crop: crop, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      crop.nameFr,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${crop.category.labelFr} · tous les ${crop.baseIntervalDays} jours',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: vertProfond.withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: sauge),
            ],
          ),
        ),
      ),
    );
  }
}
