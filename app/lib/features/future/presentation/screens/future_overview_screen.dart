import 'package:flutter/material.dart';

import '../../../../core/routing/widgets/tab_placeholder_scaffold.dart';

class FutureOverviewScreen extends StatelessWidget {
  const FutureOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScaffold(
      title: 'Future',
      icon: Icons.auto_awesome_outlined,
    );
  }
}
