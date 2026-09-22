import 'package:flutter/material.dart';

import '../../design_system/tokens/spacing.dart';
import '../../design_system/tokens/typography.dart';

/// Placeholder body for a primary tab whose real screen hasn't been built
/// yet. Each of the 5 primary tabs starts as one of these and gets replaced
/// screen-by-screen in later build-order steps — the route/shell structure
/// itself doesn't change when that happens.
class TabPlaceholderScaffold extends StatelessWidget {
  const TabPlaceholderScaffold({
    super.key,
    required this.title,
    required this.icon,
  });

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: scheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.md),
              Text(
                '$title is coming soon.',
                style: AppTypography.bodyLarge.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
