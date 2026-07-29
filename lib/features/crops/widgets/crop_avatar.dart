import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/catalog_crop.dart';

class CropAvatar extends StatelessWidget {
  const CropAvatar({
    super.key,
    required this.crop,
    this.size = 48,
    this.borderRadius,
  });

  final CatalogCrop crop;
  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(size * 0.22);

    return ClipRRect(
      borderRadius: radius,
      child: Image.asset(
        crop.image,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(radius),
      ),
    );
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
        Icons.eco_outlined,
        color: sauge,
        size: size * 0.48,
      ),
    );
  }
}
