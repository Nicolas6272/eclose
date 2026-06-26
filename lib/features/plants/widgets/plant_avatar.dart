import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_plant.dart';

class PlantAvatar extends StatelessWidget {
  const PlantAvatar({
    super.key,
    required this.plant,
    this.size = 48,
    this.borderRadius,
  });

  final CatalogPlant plant;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.22);

    if (plant.imageAsset != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.asset(
          plant.imageAsset!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _fallback(radius),
        ),
      );
    }

    return _fallback(radius);
  }

  Widget _fallback(BorderRadius radius) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: sauge.withValues(alpha: 0.15),
        borderRadius: radius,
      ),
      child: Icon(
        plant.isGeneric ? Icons.category_outlined : Icons.eco_outlined,
        color: sauge,
        size: size * 0.48,
      ),
    );
  }
}
