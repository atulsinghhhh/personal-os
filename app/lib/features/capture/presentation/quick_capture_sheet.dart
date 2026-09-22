import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/design_system/tokens/spacing.dart';
import '../../../core/design_system/widgets/app_button.dart';
import '../../../core/design_system/widgets/app_sheet.dart';
import '../../../core/design_system/widgets/app_text_field.dart';
import '../../../core/design_system/widgets/currency_input.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/providers/repository_providers.dart';
import '../../../shared/models/money.dart';
import '../../money/accounts/domain/entities/financial_account.dart';
import '../../money/transactions/domain/entities/transaction_entities.dart';
import '../../notes/domain/entities/note.dart';
import '../../projects/domain/entities/project_entities.dart';

/// Global quick capture: task, expense, or note. Expenses are amount-first
/// per the product spec — type the number, pick a category-ish note later.
Future<void> showQuickCaptureSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context: context,
    title: 'Quick capture',
    builder: (_) => const _QuickCaptureBody(),
  );
}

enum _CaptureMode { task, expense, note }

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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SegmentedButton<_CaptureMode>(
          segments: const <ButtonSegment<_CaptureMode>>[
            ButtonSegment<_CaptureMode>(
              value: _CaptureMode.task,
              label: Text('Task'),
              icon: Icon(Icons.check_circle_outline),
            ),
            ButtonSegment<_CaptureMode>(
              value: _CaptureMode.expense,
              label: Text('Expense'),
              icon: Icon(Icons.remove_circle_outline),
            ),
            ButtonSegment<_CaptureMode>(
              value: _CaptureMode.note,
              label: Text('Note'),
              icon: Icon(Icons.sticky_note_2_outlined),
            ),
          ],
          selected: <_CaptureMode>{_mode},
          onSelectionChanged: (Set<_CaptureMode> selection) =>
              setState(() => _mode = selection.first),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_mode == _CaptureMode.expense) ...<Widget>[
          CurrencyInput(currencyCode: currency, controller: _amount),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _text,
            hint: 'What was it for? (optional)',
          ),
        ] else
          AppTextField(
            controller: _text,
            hint: _mode == _CaptureMode.task
                ? 'What needs doing?'
                : 'Write it down…',
            autofocus: true,
            maxLines: _mode == _CaptureMode.note ? 3 : 1,
          ),
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: _saving ? 'Saving…' : 'Save',
          expand: true,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
