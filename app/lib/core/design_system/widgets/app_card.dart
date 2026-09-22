import 'package:flutter/material.dart';

import '../tokens/radius.dart';
import '../tokens/spacing.dart';

/// Standard content card: surfaceContainer background, lg radius, generous
/// padding. Use [onTap] to make the whole card tappable without wrapping it
/// in an InkWell at every call site.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = AppRadius.asBorderRadius(AppRadius.lg);
    final Color background =
        color ?? Theme.of(context).colorScheme.surfaceContainer;

    return Material(
      color: background,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
