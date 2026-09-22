import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/date_selector.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Sync conflicts on transactions: both versions side by side, resolved only
/// by an explicit user choice — keep mine, keep the server's, or merge.
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TransactionConflict>> conflicts =
        ref.watch(moneyConflictsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync conflicts')),
      body: conflicts.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              LoadingShimmer(height: 160),
              SizedBox(height: AppSpacing.md),
              LoadingShimmer(height: 160),
            ],
          ),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load conflicts.'),
        data: (List<TransactionConflict> all) {
          if (all.isEmpty) {
            return const EmptyStateView(
              message: 'No conflicts — everything is in sync.',
              icon: Icons.check_circle_outline,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (BuildContext context, int index) =>
                _ConflictCard(conflict: all[index]),
          );
        },
      ),
    );
  }
}

class _ConflictCard extends ConsumerWidget {
  const _ConflictCard({required this.conflict});

  final TransactionConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                size: 18,
                color: context.semanticColors.conflict,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Detected ${DateFormat.yMMMd().add_Hm().format(conflict.detectedAt.toLocal())}',
                  style: AppTypography.labelSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: _VersionColumn(
                  label: 'MINE (THIS DEVICE)',
                  version: conflict.localVersion,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _VersionColumn(
                  label: "SERVER'S",
                  version: conflict.serverVersion,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: AppButton(
                  label: 'Keep mine',
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    await ref
                        .read(transactionRepositoryProvider)
                        .resolveConflictKeepLocal(conflict.id);
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: "Keep server's",
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    await ref
                        .read(transactionRepositoryProvider)
                        .resolveConflictKeepServer(conflict.id);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Merge manually',
            expand: true,
            onPressed: () => _showMergeSheet(context, ref),
          ),
        ],
      ),
    );
  }

  /// Manual merge: a small form prefilled from the server version. Saving
  /// resolves the conflict with the merged transaction.
  Future<void> _showMergeSheet(BuildContext context, WidgetRef ref) {
    final MoneyTransaction server = conflict.serverVersion;
    final TextEditingController amount = TextEditingController(
      text: server.amount.amount.toStringAsFixed(2),
    );
    final TextEditingController note =
        TextEditingController(text: server.note ?? '');
    DateTime occurredAt = server.occurredAt.toLocal();

    return showAppBottomSheet<void>(
      context: context,
      title: 'Merge versions',
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Prefilled from the server version — adjust and save.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CurrencyInput(
                  currencyCode: server.amount.currency,
                  controller: amount,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: note,
                  label: 'Note',
                  hint: 'What was it for?',
                ),
                const SizedBox(height: AppSpacing.md),
                DateSelector(
                  label: 'Date',
                  value: occurredAt,
                  onChanged: (DateTime picked) => setState(() {
                    occurredAt = DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      occurredAt.hour,
                      occurredAt.minute,
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save merged version',
                  expand: true,
                  onPressed: () async {
                    final double? parsed = double.tryParse(amount.text);
                    if (parsed == null || parsed <= 0) return;
                    final DateTime now = DateTime.now().toUtc();
                    final String cleanNote = note.text.trim();
                    final MoneyTransaction merged = server.copyWith(
                      amount: server.amount.copyWith(amount: parsed),
                      note: cleanNote.isEmpty ? null : cleanNote,
                      occurredAt: occurredAt.toUtc(),
                      clientUpdatedAt: now,
                      updatedAt: now,
                      conflictState: TransactionConflictState.none,
                    );
                    await ref
                        .read(transactionRepositoryProvider)
                        .resolveConflictMerged(conflict.id, merged);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _VersionColumn extends StatelessWidget {
  const _VersionColumn({required this.label, required this.version});

  final String label;
  final MoneyTransaction version;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: scheme.onSurfaceVariant,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatMoney(version.amount),
              style: AppTypography.currencyMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            (version.note?.isNotEmpty ?? false) ? version.note! : 'No note',
            style: AppTypography.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            DateFormat.yMMMd()
                .add_Hm()
                .format(version.occurredAt.toLocal()),
            style: AppTypography.labelSmall.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
