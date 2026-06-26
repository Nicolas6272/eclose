import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class WelcomeStep extends StatefulWidget {
  const WelcomeStep({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  State<WelcomeStep> createState() => _WelcomeStepState();
}

class _WelcomeStepState extends State<WelcomeStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconOpacity;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _iconScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _iconOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.4, curve: Curves.easeOut),
      ),
    );

    _contentOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
    );

    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOutCubic),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          FadeTransition(
            opacity: _iconOpacity,
            child: ScaleTransition(
              scale: _iconScale,
              child: Center(
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: terracotta.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.water_drop_outlined,
                    size: 40,
                    color: terracotta,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
          FadeTransition(
            opacity: _contentOpacity,
            child: SlideTransition(
              position: _contentSlide,
              child: Column(
                children: [
                  Text(
                    'Bienvenue dans Éclose',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontSize: 28,
                          height: 1.2,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'L\'app qui t\'aide à ne jamais oublier d\'arroser tes plantes.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: 17,
                          height: 1.55,
                          color: vertProfond.withValues(alpha: 0.65),
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 3),
          FadeTransition(
            opacity: _contentOpacity,
            child: FilledButton(
              onPressed: widget.onNext,
              child: const Text('Commencer'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
