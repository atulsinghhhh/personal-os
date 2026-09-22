import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/rows.dart';
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
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
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

  CategoryKind get _categoryKind =>
      widget.kind == TransactionKind.income ? CategoryKind.income : CategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final String profileCurrency =
        ref.watch(currentProfileProvider).value?.defaultCurrency ?? 'USD';
    final List<FinancialAccount> accounts =
        ref.watch(moneyAccountsProvider).value ?? <FinancialAccount>[];
    final AsyncValue<List<TransactionCategory>> categoriesAsync =
        ref.watch(moneyCategoriesProvider);
    final List<Project> projects = ref.watch(moneyProjectsProvider).value ?? <Project>[];

    // Lazily seed the default category set the first time this screen finds
    // none — mirrors onboarding for users who skipped it.
    categoriesAsync.whenData((List<TransactionCategory> all) {
      if (all.isEmpty && !_seededCategories) {
        _seededCategories = true;
        final String? userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
        if (userId != null) {
          unawaited(
            ref
                .read(transactionCategoryRepositoryProvider)
                .seedDefaults(userId, currency: profileCurrency),
          );
        }
      }
    });

    final List<TransactionCategory> categories = (categoriesAsync.value ?? <TransactionCategory>[])
        .where((TransactionCategory c) => c.kind == _categoryKind)
        .toList(growable: false);

    final FinancialAccount? selectedAccount = _account ?? (accounts.isEmpty ? null : accounts.first);
    final String currency = selectedAccount?.openingBalance.currency ?? profileCurrency;
    final bool isExpense = widget.kind == TransactionKind.expense;

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 130),
              children: <Widget>[
                SizedBox(
                  height: 44,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.canPop() ? context.pop() : context.go(RoutePaths.money),
                    child: Row(
                      children: <Widget>[
                        const LumaIcon(LumaIcons.chevronLeft, size: 22, color: LumaColors.ink2),
                        const SizedBox(width: 2),
                        Text('Back', style: lumaSans(size: 15, color: LumaColors.ink2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(isExpense ? 'Add expense' : 'Add income',
                    style: lumaSerif(size: 34, height: 1.05)),
                const SizedBox(height: 24),
                CurrencyInput(currencyCode: currency, controller: _amount),
                const SizedBox(height: 20),
                LumaMetaRow(
                  label: 'Account',
                  value: selectedAccount?.name ?? 'Default cash account will be created',
                  onTap: accounts.isEmpty
                      ? null
                      : () async {
                          final FinancialAccount? picked =
                              await showAccountPicker(context, accounts: accounts);
                          if (picked != null) setState(() => _account = picked);
                        },
                ),
                LumaMetaRow(
                  label: 'Category',
                  value: _category?.name ?? 'None (optional)',
                  onTap: categories.isEmpty
                      ? null
                      : () async {
                          final TransactionCategory? picked =
                              await showCategoryPicker(context, categories: categories);
                          if (picked != null) setState(() => _category = picked);
                        },
                ),
                LumaMetaRow(
                  label: 'Project',
                  value: _project?.title ?? 'Not linked (optional)',
                  onTap: projects.isEmpty
                      ? null
                      : () async {
                          final ProjectPick? picked = await showProjectPicker(
                            context,
                            projects: projects,
                            allowClear: _project != null,
                          );
                          if (picked != null) setState(() => _project = picked.project);
                        },
                ),
                LumaMetaRow(
                  label: 'Date',
                  value: _date == null ? 'Today' : DateFormat.yMMMd().format(_date!),
                  onTap: () async {
                    final DateTime now = DateTime.now();
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _date ?? now,
                      firstDate: DateTime(now.year - 5),
                      lastDate: now,
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _note,
                  minLines: 1,
                  maxLines: 3,
                  style: lumaSans(size: 15),
                  cursorColor: LumaColors.ink,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Note (optional) — what was it for?',
                    hintStyle: lumaSans(size: 15, color: LumaColors.ink3),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 20 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: LumaColors.ground,
                border: Border(top: BorderSide(color: LumaColors.hairline)),
              ),
              child: LumaPrimaryButton(
                label: _saving ? 'Saving…' : (isExpense ? 'Save expense' : 'Save income'),
                height: 52,
                onTap: _saving ? null : () => _save(profileCurrency),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String profileCurrency) async {
    final double? amount = double.tryParse(_amount.text);
    final String? userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
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
        occurredAt =
            DateTime(_date!.year, _date!.month, _date!.day, local.hour, local.minute).toUtc();
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
              amount: Money(amount: amount, currency: account.openingBalance.currency),
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
  Future<FinancialAccount> _ensureDefaultAccount(String userId, String currency) async {
    final List<FinancialAccount> accounts =
        await ref.read(financialAccountRepositoryProvider).watchAll().first;
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
