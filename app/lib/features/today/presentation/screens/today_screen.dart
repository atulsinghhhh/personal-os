import 'package:flutter/material.dart';

import '../../../../core/routing/widgets/tab_placeholder_scaffold.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScaffold(
      title: 'Today',
      icon: Icons.wb_sunny_outlined,
    );
  }
}
