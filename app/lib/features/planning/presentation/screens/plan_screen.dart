import 'package:flutter/material.dart';

import '../../../../core/routing/widgets/tab_placeholder_scaffold.dart';

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScaffold(
      title: 'Plan',
      icon: Icons.calendar_month_outlined,
    );
  }
}
