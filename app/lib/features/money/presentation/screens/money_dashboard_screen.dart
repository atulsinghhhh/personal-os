import 'package:flutter/material.dart';

import '../../../../core/routing/widgets/tab_placeholder_scaffold.dart';

class MoneyDashboardScreen extends StatelessWidget {
  const MoneyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TabPlaceholderScaffold(
      title: 'Money',
      icon: Icons.account_balance_wallet_outlined,
    );
  }
}
