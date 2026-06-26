import 'package:flutter/material.dart';

import '../widgets/onboarding_progress.dart';

class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.child,
    this.onBack,
  });

  final int currentStep;
  final int totalSteps;
  final Widget child;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 24, 8),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: OnboardingProgress(
                      currentStep: currentStep,
                      totalSteps: totalSteps,
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
