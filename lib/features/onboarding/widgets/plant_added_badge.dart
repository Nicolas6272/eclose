import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class PlantAddedBadge extends StatefulWidget {
  const PlantAddedBadge({super.key, this.size = 112});

  final double size;

  @override
  State<PlantAddedBadge> createState() => _PlantAddedBadgeState();
}

class _PlantAddedBadgeState extends State<PlantAddedBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _ringScale;
  late final Animation<double> _ringOpacity;
  late final Animation<double> _mainScale;
  late final Animation<double> _plantOpacity;
  late final Animation<double> _badgeScale;
  late final Animation<double> _checkProgress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );

    _ringScale = Tween<double>(begin: 0.7, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _ringOpacity = Tween<double>(begin: 0.45, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.55, curve: Curves.easeOut),
      ),
    );

    _mainScale = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _plantOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
      ),
    );

    _badgeScale = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.elasticOut),
      ),
    );

    _checkProgress = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final badgeSize = size * 0.36;

    return SizedBox(
      width: size * 1.2,
      height: size * 1.2,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: _ringScale.value,
                child: Opacity(
                  opacity: _ringOpacity.value,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: sauge.withValues(alpha: 0.45),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: _mainScale.value,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: sauge.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sauge.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: sauge.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Opacity(
                    opacity: _plantOpacity.value,
                    child: Icon(
                      Icons.eco_rounded,
                      size: size * 0.42,
                      color: vertProfond,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: size * 0.08,
                bottom: size * 0.08,
                child: Transform.scale(
                  scale: _badgeScale.value,
                  child: Container(
                    width: badgeSize,
                    height: badgeSize,
                    decoration: BoxDecoration(
                      color: sauge,
                      shape: BoxShape.circle,
                      border: Border.all(color: creme, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: sauge.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      painter: _CheckPainter(
                        progress: _checkProgress.value,
                        color: vertProfond,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.11
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final start = Offset(size.width * 0.28, size.height * 0.52);
    final mid = Offset(size.width * 0.44, size.height * 0.68);
    final end = Offset(size.width * 0.74, size.height * 0.36);

    final path = Path()..moveTo(start.dx, start.dy);

    if (progress < 0.5) {
      final t = progress / 0.5;
      path.lineTo(
        start.dx + (mid.dx - start.dx) * t,
        start.dy + (mid.dy - start.dy) * t,
      );
    } else {
      path.lineTo(mid.dx, mid.dy);
      final t = (progress - 0.5) / 0.5;
      path.lineTo(
        mid.dx + (end.dx - mid.dx) * t,
        mid.dy + (end.dy - mid.dy) * t,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
