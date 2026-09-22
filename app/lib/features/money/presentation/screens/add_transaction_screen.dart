import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/date_selector.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_pickers.dart';

/// Amount-first entry for a new expense or income. One screen serves both
/// kinds (routed as /money/add-expense and /money/add-income).
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, required this.kind});

  final TransactionKind kind;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  FinancialAccount? _account;
  TransactionCategory? _category;
  Project? _project;
  DateTime? _date;
  bool _saving = false;
  bool _seededCategories = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  CategoryKind get _categoryKind => widget.kind == TransactionKind.income
      ? CategoryKind.income
      : CategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final String profileCurrency =
        ref.watch(currentProfileProvider).value?.defaultCurrency ?? 'USD';
    final List<FinancialAccount> accounts =
        ref.watch(moneyAccountsProvider).value ?? <FinancialAccount>[];
    final AsyncValue<List<TransactionCategory>> categoriesAsync =
        ref.watch(moneyCategoriesProvider);
    final List<Project> projects =
        ref.watch(moneyProjectsProvider).value ?? <Project>[];

    // Lazily seed the default category set the first time this screen finds
    // none — mirrors onboarding for users who skipped it.
    categoriesAsync.whenData((List<TransactionCategory> all) {
      if (all.isEmpty && !_seededCategories) {
        _seededCategories = true;
        final String? userId =
            ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (userId != null) {
          unawaited(
            ref
                .read(transactionCategoryRepositoryProvider)
                .seedDefaults(userId, currency: profileCurrency),
          );
        }
      }
    });

    final List<TransactionCategory> categories =
        (categoriesAsync.value ?? <TransactionCategory>[])
            .where((TransactionCategory c) => c.kind == _categoryKind)
            .toList(growable: false);

    final FinancialAccount? selectedAccount =
        _account ?? (accounts.isEmpty ? null : accounts.first);
    final String currency =
        selectedAccount?.openingBalance.currency ?? profileCurrency;
    final bool isExpense = widget.kind == TransactionKind.expense;

    return Scaffold(
      appBar: AppBar(
        title: Text(isExpense ? 'Add expense' : 'Add income'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: <Widget>[
            const SizedBox(height: AppSpacing.lg),
            CurrencyInput(currencyCode: currency, controller: _amount),
            const SizedBox(height: AppSpacing.xl),
            AppListRow(
              title: 'Account',
              subtitle: selectedAccount?.name ??
                  'Default cash account will be created',
              leading: const Icon(Icons.account_balance_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: accounts.isEmpty
                  ? null
                  : () async {
                      final FinancialAccount? picked =
                          await showAccountPicker(context,
                              accounts: accounts);
                      if (picked != null) {
                        setState(() => _account = picked);
                      }
                    },
            ),
            AppListRow(
              title: 'Category',
              subtitle: _category?.name ?? 'None (optional)',
              leading: const Icon(Icons.category_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: categories.isEmpty
                  ? null
                  : () async {
                      final TransactionCategory? picked =
                          await showCategoryPicker(context,
                              categories: categories);
                      if (picked != null) {
                        setState(() => _category = picked);
                      }
                    },
            ),
            AppListRow(
              title: 'Project',
              subtitle: _project?.title ?? 'Not linked (optional)',
              leading: const Icon(Icons.folder_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: projects.isEmpty
                  ? null
                  : () async {
                      final ProjectPick? picked = await showProjectPicker(
                        context,
                        projects: projects,
                        allowClear: _project != null,
                      );
                      if (picked != null) {
                        setState(() => _project = picked.project);
                      }
                    },
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _note,
              label: 'Note (optional)',
              hint: 'What was it for?',
            ),
            const SizedBox(height: AppSpacing.md),
            DateSelector(
              label: 'Date (defaults to now)',
              value: _date,
              lastDate: DateTime.now(),
              onChanged: (DateTime picked) => setState(() => _date = picked),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: _saving
                  ? 'Saving…'
                  : (isExpense ? 'Save expense' : 'Save income'),
              expand: true,
              onPressed: _saving ? null : () => _save(profileCurrency),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String profileCurrency) async {
    final double? amount = double.tryParse(_amount.text);
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (amount == null || amount <= 0 || userId == null) return;
    setState(() => _saving = true);

    try {
      final FinancialAccount account =
          _account ?? await _ensureDefaultAccount(userId, profileCurrency);
      final DateTime now = DateTime.now().toUtc();
      final DateTime occurredAt;
      if (_date == null) {
        occurredAt = now;
      } else {
        final DateTime local = DateTime.now();
        occurredAt = DateTime(
          _date!.year,
          _date!.month,
          _date!.day,
          local.hour,
          local.minute,
        ).toUtc();
      }
      final String note = _note.text.trim();
      await ref.read(transactionRepositoryProvider).create(
            MoneyTransaction(
              id: const Uuid().v4(),
              userId: userId,
              accountId: account.id,
              categoryId: _category?.id,
              projectId: _project?.id,
              kind: widget.kind,
              amount: Money(
                amount: amount,
                currency: account.openingBalance.currency,
              ),
              occurredAt: occurredAt,
              note: note.isEmpty ? null : note,
              clientUpdatedAt: now,
              serverUpdatedAt: now,
              conflictState: TransactionConflictState.none,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (mounted) context.go('/money');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// First account wins; if the user has none, create a Cash account in the
  /// profile currency (same bootstrap as quick capture).
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
}
