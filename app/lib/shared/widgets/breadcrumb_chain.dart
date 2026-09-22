import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/design_system/tokens/spacing.dart';
import '../../core/design_system/tokens/typography.dart';
import '../../core/design_system/widgets/app_card.dart';
import '../models/money.dart';
import '../providers/chain_providers.dart';

/// Renders the core product relationship on detail screens:
/// Task -> Project -> Milestone -> Goal -> Life area -> Vision, plus the
/// time and money invested at the level being viewed. Built once, reused on
/// Task/Project/Goal detail.
class BreadcrumbChain extends StatelessWidget {
  const BreadcrumbChain({super.key, required this.chain, this.title = 'WHY?'});

  final EntityChain chain;
  final String title;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    final List<(IconData, String)> levels = <(IconData, String)>[
      if (chain.project != null)
        (Icons.folder_outlined, chain.project!.title),
      if (chain.milestone != null)
        (Icons.flag_outlined, chain.milestone!.title),
      if (chain.goal != null) (Icons.track_changes, chain.goal!.title),
      if (chain.lifeArea != null)
        (Icons.category_outlined, chain.lifeArea!.name),
      if (chain.vision != null)
        (Icons.auto_awesome_outlined, chain.vision!.title),
    ];

    final bool hasInvestments =
        chain.timeInvestedMinutes > 0 || chain.moneyInvested.isNotEmpty;

    if (levels.isEmpty && !hasInvestments) {
      return AppCard(
        child: Text(
          'Not connected to a project or goal yet.',
          style: AppTypography.bodyMedium.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: AppTypography.labelSmall.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < levels.length; i++) ...<Widget>[
            Row(
              children: <Widget>[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.xs,
                      right: AppSpacing.sm,
                    ),
                    child: Icon(
                      Icons.subdirectory_arrow_right,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                Icon(levels[i].$1, size: 16, color: scheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    levels[i].$2,
                    style: AppTypography.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (i < levels.length - 1)
              const SizedBox(height: AppSpacing.xs),
          ],
          if (hasInvestments) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                if (chain.timeInvestedMinutes > 0)
                  _InvestmentChip(
                    icon: Icons.timer_outlined,
                    label: formatMinutes(chain.timeInvestedMinutes),
                  ),
                for (final Money money in chain.moneyInvested)
                  _InvestmentChip(
                    icon: Icons.payments_outlined,
                    label: NumberFormat.simpleCurrency(name: money.currency)
                        .format(money.amount),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String formatMinutes(int minutes) {
  if (minutes < 60) return '${minutes}m';
  return '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m';
}

class _InvestmentChip extends StatelessWidget {
  const _InvestmentChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(label, style: AppTypography.labelMedium),
        ],
      ),
    );
  }
}
