import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Design "Transactions": search, a category chip row, and day-grouped rows
/// with letter avatars — a pinned "Add expense" bar replaces the old FAB.
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  bool _searchOpen = false;
  final TextEditingController _search = TextEditingController();
  String? _categoryId;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(moneyAllTransactionsProvider);
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];
    final List<FinancialAccount> accounts =
        ref.watch(moneyAllAccountsProvider).value ?? <FinancialAccount>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 52, 20, 130),
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text('Transactions', style: lumaSerif(size: 36, height: 1.05)),
                    Semantics(
                      label: 'Search',
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _searchOpen = !_searchOpen),
                        child: const SizedBox(
                          width: 44,
                          height: 44,
                          child: Center(
                            child: LumaIcon(LumaIcons.search,
                                size: 20, color: LumaColors.ink2),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_searchOpen) ...<Widget>[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _search,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    style: lumaSans(size: 15),
                    cursorColor: LumaColors.ink,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'Search notes and categories',
                      hintStyle: lumaSans(size: 15, color: LumaColors.ink3),
                    ),
                  ),
                  const LumaHairline(),
                ],
                const SizedBox(height: 20),
                if (categories.isNotEmpty)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: <Widget>[
                        LumaChip(
                          label: 'All',
                          selected: _categoryId == null,
                          onTap: () => setState(() => _categoryId = null),
                        ),
                        for (final TransactionCategory category in categories) ...<Widget>[
                          const SizedBox(width: 8),
                          LumaChip(
                            label: category.name,
                            selected: _categoryId == category.id,
                            onTap: () => setState(
                                () => _categoryId = _categoryId == category.id ? null : category.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                transactions.when(
                  loading: () => const SizedBox(height: 200),
                  error: (Object error, _) => Text('Could not load transactions.',
                      style: lumaSans(size: 14, color: LumaColors.ink3)),
                  data: (List<MoneyTransaction> all) {
                    final String query = _search.text.trim().toLowerCase();
                    final List<MoneyTransaction> filtered = all.where((MoneyTransaction t) {
                      if (_categoryId != null && t.categoryId != _categoryId) return false;
                      if (query.isEmpty) return true;
                      final String title = _titleFor(t, categories).toLowerCase();
                      return title.contains(query);
                    }).toList(growable: false);

                    if (filtered.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: GestureDetector(
                          onTap: () => context.go('/money/add-expense'),
                          child: Text(
                            all.isEmpty
                                ? 'No transactions yet — add your first expense.'
                                : 'Nothing matches.',
                            style: lumaSans(
                                size: 14,
                                weight: FontWeight.w500,
                                color: LumaColors.accent),
                          ),
                        ),
                      );
                    }

                    final List<(DateTime, List<MoneyTransaction>)> groups =
                        <(DateTime, List<MoneyTransaction>)>[];
                    for (final MoneyTransaction transaction in filtered) {
                      final DateTime local = transaction.occurredAt.toLocal();
                      final DateTime day = DateTime(local.year, local.month, local.day);
                      if (groups.isNotEmpty && groups.last.$1 == day) {
                        groups.last.$2.add(transaction);
                      } else {
                        groups.add((day, <MoneyTransaction>[transaction]));
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        for (int i = 0; i < groups.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: 24),
                          LumaEyebrow(_dayLabel(groups[i].$1)),
                          const SizedBox(height: 8),
                          for (final MoneyTransaction transaction in groups[i].$2)
                            _TransactionRow(
                              transaction: transaction,
                              title: _titleFor(transaction, categories),
                              accountName: _accountName(transaction, accounts),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                  20, 14, 20, 20 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: LumaColors.ground,
                border: Border(top: BorderSide(color: LumaColors.hairline)),
              ),
              child: LumaPrimaryButton(
                label: 'Add expense',
                height: 52,
                leading: const LumaIcon(LumaIcons.plus, size: 16, color: Colors.white),
                onTap: () => context.go('/money/add-expense'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime day) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    if (day == today) return 'Today';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('EEEE, MMM d').format(day);
  }

  static String _titleFor(
    MoneyTransaction transaction,
    List<TransactionCategory> categories,
  ) {
    for (final TransactionCategory category in categories) {
      if (category.id == transaction.categoryId) return category.name;
    }
    final String? note = transaction.note;
    if (note != null && note.isNotEmpty) return note;
    return transactionKindLabel(transaction.kind);
  }

  static String _accountName(
    MoneyTransaction transaction,
    List<FinancialAccount> accounts,
  ) {
    for (final FinancialAccount account in accounts) {
      if (account.id == transaction.accountId) return account.name;
    }
    return 'Unknown account';
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.title,
    required this.accountName,
  });

  final MoneyTransaction transaction;
  final String title;
  final String accountName;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/money/transactions/${transaction.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LumaColors.hairline)),
        ),
        child: Row(
          children: <Widget>[
            MoneyLetterAvatar(label: title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: lumaSans(size: 14.5, weight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(accountName, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
                ],
              ),
            ),
            SignedAmountText(transaction: transaction),
          ],
        ),
      ),
    );
  }
}
