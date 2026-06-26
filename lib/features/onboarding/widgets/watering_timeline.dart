import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';

class WateringTimeline extends StatelessWidget {
  const WateringTimeline({
    super.key,
    required this.daysUntilWatering,
    required this.nextWateringDate,
    this.progress = 1,
  });

  final int daysUntilWatering;
  final DateTime nextWateringDate;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final daysLabel = daysUntilWatering == 0
        ? 'aujourd\'hui'
        : daysUntilWatering == 1
            ? 'demain'
            : 'dans $daysUntilWatering jours';

    return Column(
      children: [
        Row(
          children: [
            Text(
              'Aujourd\'hui',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: vertProfond.withValues(alpha: 0.45),
                    fontSize: 13,
                  ),
            ),
            const Spacer(),
            Text(
              daysLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: terracotta,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final trackWidth = constraints.maxWidth;
            final dotSize = 10.0;
            final fillWidth = (trackWidth - dotSize) * progress.clamp(0, 1);

            return SizedBox(
              height: dotSize,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: dotSize / 2,
                    right: dotSize / 2,
                    top: dotSize / 2 - 1,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: sauge.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: dotSize / 2,
                    width: fillWidth,
                    top: dotSize / 2 - 1,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: terracotta.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    child: _TimelineDot(filled: true, size: dotSize),
                  ),
                  Positioned(
                    right: 0,
                    child: _TimelineDot(
                      filled: progress >= 1,
                      size: dotSize,
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        Text(
          formatFrenchDate(nextWateringDate),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: vertProfond.withValues(alpha: 0.4),
              ),
        ),
      ],
    );
  }
}

class _TimelineDot extends StatelessWidget {
  const _TimelineDot({
    required this.filled,
    required this.size,
    this.icon,
  });

  final bool filled;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (icon != null && filled) {
      return Icon(icon, size: size + 6, color: terracotta);
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: filled ? terracotta : creme,
        border: Border.all(
          color: filled ? terracotta : sauge.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
    );
  }
}
