import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/design_system/widgets/currency_input.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../luma/theme/tokens.dart';
import '../../../luma/widgets/buttons.dart';
import '../../../luma/widgets/luma_icons.dart';
import '../../../shared/models/money.dart';
import '../../money/accounts/domain/entities/financial_account.dart';
import '../../money/transactions/domain/entities/transaction_entities.dart';
import '../../notes/domain/entities/note.dart';
import '../../projects/domain/entities/project_entities.dart';

/// Design 09 "Quick capture": bottom sheet with a big serif input, type
/// chips and one save action. Task, expense, or note — expenses are
/// amount-first per the product spec.
Future<void> showQuickCaptureSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LumaColors.ground,
    barrierColor: const Color(0x521B1B19),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _QuickCaptureBody(),
  );
}

enum _CaptureMode { task, note, expense }

class _QuickCaptureBody extends ConsumerStatefulWidget {
  const _QuickCaptureBody();

  @override
  ConsumerState<_QuickCaptureBody> createState() => _QuickCaptureBodyState();
}

class _QuickCaptureBodyState extends ConsumerState<_QuickCaptureBody> {
  _CaptureMode _mode = _CaptureMode.task;
  final TextEditingController _text = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  bool _saving = false;

  static const Map<_CaptureMode, String> _labels = <_CaptureMode, String>{
    _CaptureMode.task: 'Task',
    _CaptureMode.note: 'Note',
    _CaptureMode.expense: 'Expense',
  };

  static const Map<_CaptureMode, String> _hints = <_CaptureMode, String>{
    _CaptureMode.task: 'Scheduled for today',
    _CaptureMode.note: 'Saved to Inbox · sort later',
    _CaptureMode.expense: 'Amount · category · account',
  };

  @override
  void dispose() {
    _text.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null || _saving) return;
    setState(() => _saving = true);

    final DateTime now = DateTime.now().toUtc();
    // Calendar dates use LOCAL components in a UTC container — the user's
    // "today", not UTC's (which can differ around midnight).
    final DateTime local = DateTime.now();
    final DateTime today = DateTime.utc(local.year, local.month, local.day);
    final String id = const Uuid().v4();

    try {
      switch (_mode) {
        case _CaptureMode.task:
          if (_text.text.trim().isEmpty) return;
          await ref.read(taskRepositoryProvider).create(
                Task(
                  id: id,
                  userId: userId,
                  title: _text.text.trim(),
                  status: TaskStatus.todo,
                  priority: 0,
                  scheduledDate: today,
                  actualMinutes: 0,
                  sortOrder: 0,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        case _CaptureMode.expense:
          final double? amount = double.tryParse(_amount.text);
          if (amount == null || amount <= 0) return;
          final String currency = ref
                  .read(currentProfileProvider)
                  .value
                  ?.defaultCurrency ??
              'USD';
          // Expenses need an account; use (or lazily create) a default
          // Cash account so capture stays friction-free.
          final FinancialAccount account =
              await _ensureDefaultAccount(userId, currency);
          await ref.read(transactionRepositoryProvider).create(
                MoneyTransaction(
                  id: id,
                  userId: userId,
                  accountId: account.id,
                  kind: TransactionKind.expense,
                  amount: Money(amount: amount, currency: currency),
                  occurredAt: now,
                  note: _text.text.trim().isEmpty ? null : _text.text.trim(),
                  clientUpdatedAt: now,
                  serverUpdatedAt: now,
                  conflictState: TransactionConflictState.none,
                  createdAt: now,
                  updatedAt: now,
                ),
              );
        case _CaptureMode.note:
          if (_text.text.trim().isEmpty) return;
          await ref.read(noteRepositoryProvider).create(
                Note(
                  id: id,
                  userId: userId,
                  body: _text.text.trim(),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<FinancialAccount> _ensureDefaultAccount(
    String userId,
    String currency,
  ) async {
    final List<FinancialAccount> accounts = await ref
        .read(financialAccountRepositoryProvider)
        .watchAll()
        .first;
    if (accounts.isNotEmpty) return accounts.first;

    final DateTime now = DateTime.now().toUtc();
    final FinancialAccount cash = FinancialAccount(
      id: const Uuid().v4(),
      userId: userId,
      name: 'Cash',
      type: AccountType.cash,
      openingBalance: Money(amount: 0, currency: currency),
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(financialAccountRepositoryProvider).create(cash);
    return cash;
  }

  @override
  Widget build(BuildContext context) {
    final String currency =
        ref.watch(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('CAPTURE', style: lumaEyebrow()),
                Semantics(
                  label: 'Close',
                  button: true,
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: LumaIcon(LumaIcons.close,
                            size: 20, color: LumaColors.ink2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_mode == _CaptureMode.expense) ...<Widget>[
              CurrencyInput(currencyCode: currency, controller: _amount),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                style: lumaSerif(size: 28, height: 1.15),
                cursorColor: LumaColors.ink,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: 'What was it for? (optional)',
                  hintStyle: lumaSerif(
                      size: 28, height: 1.15, color: LumaColors.ink3),
                ),
              ),
            ] else
              TextField(
                controller: _text,
                autofocus: true,
                maxLines: _mode == _CaptureMode.note ? 3 : 1,
                style: lumaSerif(size: 28, height: 1.15),
                cursorColor: LumaColors.ink,
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  hintText: _mode == _CaptureMode.task
                      ? 'What needs doing?'
                      : 'Write it down…',
                  hintStyle: lumaSerif(
                      size: 28, height: 1.15, color: LumaColors.ink3),
                ),
              ),
            const SizedBox(height: 20),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: <Widget>[
                  for (final _CaptureMode mode in _CaptureMode.values) ...<Widget>[
                    if (mode != _CaptureMode.values.first)
                      const SizedBox(width: 8),
                    LumaChip(
                      label: _labels[mode]!,
                      selected: _mode == mode,
                      onTap: () => setState(() => _mode = mode),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                const LumaIcon(LumaIcons.sparkle,
                    size: 16, color: LumaColors.ink2),
                const SizedBox(width: 8),
                Text(_hints[_mode]!,
                    style: lumaSans(size: 13, color: LumaColors.ink2)),
              ],
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: LumaColors.hairline),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                Expanded(
                  child: LumaPrimaryButton(
                    label: _saving ? 'Saving…' : 'Save ${_labels[_mode]!}',
                    height: 52,
                    onTap: _saving ? null : _save,
                  ),
                ),
                const SizedBox(width: 10),
                Semantics(
                  label: 'More options',
                  button: true,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      border: Border.all(color: LumaColors.hairline),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Center(
                      child: LumaIcon(LumaIcons.ellipsis,
                          size: 20, color: LumaColors.ink2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Capture first. Everything can be organized later from Inbox.',
              textAlign: TextAlign.center,
              style: lumaSans(size: 12.5, color: LumaColors.ink3),
            ),
          ],
        ),
      ),
    );
  }
}
