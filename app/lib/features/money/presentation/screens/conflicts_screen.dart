import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Sync conflicts on transactions: both versions side by side, resolved only
/// by an explicit user choice — keep mine, keep the server's, or merge.
class ConflictsScreen extends ConsumerWidget {
  const ConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<TransactionConflict>> conflicts = ref.watch(moneyConflictsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Text('Sync conflicts', style: lumaSerif(size: 32, height: 1.05)),
          const SizedBox(height: 28),
          conflicts.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load conflicts.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<TransactionConflict> all) {
              if (all.isEmpty) {
                return Text('No conflicts — everything is in sync.',
                    style: lumaSans(size: 14, color: LumaColors.ink3));
              }
              return Column(
                children: <Widget>[
                  for (int i = 0; i < all.length; i++) ...<Widget>[
                    if (i > 0) const SizedBox(height: 28),
                    _ConflictBlock(conflict: all[i]),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ConflictBlock extends ConsumerWidget {
  const _ConflictBlock({required this.conflict});

  final TransactionConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            const LumaIcon(LumaIcons.flag, size: 15, color: LumaColors.warning),
            const SizedBox(width: 8),
            Text(
              'Detected ${DateFormat.yMMMd().add_Hm().format(conflict.detectedAt.toLocal())}',
              style: lumaSans(size: 12.5, color: LumaColors.ink3),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
                child: _VersionColumn(label: 'Mine (this device)', version: conflict.localVersion)),
            const SizedBox(width: 12),
            Expanded(child: _VersionColumn(label: "Server's", version: conflict.serverVersion)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: LumaSecondaryButton(
                label: 'Keep mine',
                onTap: () async {
                  await ref.read(transactionRepositoryProvider).resolveConflictKeepLocal(conflict.id);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: LumaSecondaryButton(
                label: "Keep server's",
                onTap: () async {
                  await ref.read(transactionRepositoryProvider).resolveConflictKeepServer(conflict.id);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LumaPrimaryButton(
          label: 'Merge manually',
          height: 52,
          onTap: () => _showMergeSheet(context, ref),
        ),
      ],
    );
  }

  /// Manual merge: a small form prefilled from the server version. Saving
  /// resolves the conflict with the merged transaction.
  Future<void> _showMergeSheet(BuildContext context, WidgetRef ref) {
    final MoneyTransaction server = conflict.serverVersion;
    final TextEditingController amount =
        TextEditingController(text: server.amount.amount.toStringAsFixed(2));
    final TextEditingController note = TextEditingController(text: server.note ?? '');
    DateTime occurredAt = server.occurredAt.toLocal();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LumaColors.ground,
      barrierColor: const Color(0x521B1B19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 38,
                        height: 5,
                        decoration: BoxDecoration(
                          color: LumaColors.hairline,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const LumaEyebrow('Merge versions'),
                    const SizedBox(height: 10),
                    Text('Prefilled from the server version — adjust and save.',
                        style: lumaSans(size: 13, color: LumaColors.ink3)),
                    const SizedBox(height: 16),
                    CurrencyInput(
                        currencyCode: server.amount.currency, controller: amount, autofocus: false),
                    const SizedBox(height: 16),
                    TextField(
                      controller: note,
                      style: lumaSans(size: 15),
                      cursorColor: LumaColors.ink,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'What was it for?',
                        hintStyle: lumaSans(size: 15, color: LumaColors.ink3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: occurredAt,
                          firstDate: DateTime(occurredAt.year - 5),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() => occurredAt = DateTime(
                                picked.year,
                                picked.month,
                                picked.day,
                                occurredAt.hour,
                                occurredAt.minute,
                              ));
                        }
                      },
                      child: Text('Date · ${DateFormat.yMMMd().format(occurredAt)}',
                          style: lumaSans(size: 14, color: LumaColors.ink2)),
                    ),
                    const SizedBox(height: 24),
                    LumaPrimaryButton(
                      label: 'Save merged version',
                      height: 52,
                      onTap: () async {
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
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      },
                    ),
                  ],
                ),
              ),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: LumaColors.sunken,
        borderRadius: BorderRadius.circular(LumaRadius.button),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LumaEyebrow(label),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(formatMoney(version.amount),
                style: lumaSans(size: 17, weight: FontWeight.w500)),
          ),
          const SizedBox(height: 6),
          Text(
            (version.note?.isNotEmpty ?? false) ? version.note! : 'No note',
            style: lumaSans(size: 13, color: LumaColors.ink2),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat.yMMMd().add_Hm().format(version.occurredAt.toLocal()),
            style: lumaSans(size: 11.5, color: LumaColors.ink3),
          ),
        ],
      ),
    );
  }
}
