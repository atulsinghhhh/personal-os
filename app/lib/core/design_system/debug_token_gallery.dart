import 'package:flutter/material.dart';

import 'theme/theme_extensions.dart';
import 'tokens/radius.dart';
import 'tokens/spacing.dart';
import 'tokens/typography.dart';

/// Temporary scaffolding screen (not part of the Phase 1 screen set) used to
/// visually verify every design token and theme mode renders correctly.
/// Reachable only via a debug route; safe to delete once the real screens
/// exercise the same tokens.
class DebugTokenGallery extends StatelessWidget {
  const DebugTokenGallery({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final AppSemanticColors semantic = context.semanticColors;

    return Scaffold(
      appBar: AppBar(title: const Text('Design Token Gallery')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Text('Typography', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Text('Display large', style: AppTypography.displayLarge),
          Text('Headline large', style: AppTypography.headlineLarge),
          Text('Title large', style: AppTypography.titleLarge),
          Text('Body large', style: AppTypography.bodyLarge),
          Text('Label large', style: AppTypography.labelLarge),
          Text('₹1,24,500.00', style: AppTypography.currencyLarge),
          Text('₹840.00', style: AppTypography.currencyMedium),
          const SizedBox(height: AppSpacing.xl),
          Text('Semantic colors', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _Swatch('income', semantic.income),
              _Swatch('expense', semantic.expense),
              _Swatch('warning', semantic.warning),
              _Swatch('conflict', semantic.conflict),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Life area accents', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (int i = 0; i < semantic.lifeAreaAccents.length; i++)
                _Swatch('accent $i', semantic.lifeAreaAccents[i]),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Cards & radius', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: AppRadius.asBorderRadius(AppRadius.lg),
            ),
            child: const Text('surfaceContainer card, lg radius'),
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: AppRadius.asBorderRadius(AppRadius.xl),
            ),
            child: const Text('surfaceContainerHigh card, xl radius'),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: () {}, child: const Text('Filled button')),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Outlined button'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: () {}, child: const Text('Text button')),
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch(this.label, this.color);

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: AppRadius.asBorderRadius(AppRadius.md),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(label, style: AppTypography.labelSmall),
      ],
    );
  }
}
