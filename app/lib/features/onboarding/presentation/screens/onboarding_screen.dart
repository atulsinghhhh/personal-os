import 'package:flutter/material.dart';

import '../../../../core/routing/widgets/tab_placeholder_scaffold.dart';

/// Placeholder — the real progressive onboarding flow (name, life areas,
/// vision, currency, all skippable) is built in a later step.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScaffold(
      title: 'Onboarding',
      icon: Icons.flag_outlined,
    );
  }
}
