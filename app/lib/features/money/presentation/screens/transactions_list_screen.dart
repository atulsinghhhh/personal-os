import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// All transactions, grouped by day (newest first). Rows show category/note,
/// account, and the signed amount.
class TransactionsListScreen extends ConsumerWidget {
  const TransactionsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(moneyAllTransactionsProvider);
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];
    final List<FinancialAccount> accounts =
        ref.watch(moneyAllAccountsProvider).value ?? <FinancialAccount>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/money/add-expense'),
        icon: const Icon(Icons.add),
        label: const Text('Expense'),
      ),
      body: transactions.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              LoadingShimmer(height: 80),
              SizedBox(height: AppSpacing.md),
              LoadingShimmer(height: 80),
            ],
          ),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load transactions.'),
        data: (List<MoneyTransaction> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message: 'No transactions yet — add your first expense.',
              icon: Icons.receipt_long_outlined,
              ctaLabel: 'Add expense',
              onCta: () => context.go('/money/add-expense'),
            );
          }
          // Group by local calendar day, preserving newest-first ordering
          // from the repository stream.
          final List<(DateTime, List<MoneyTransaction>)> groups =
              <(DateTime, List<MoneyTransaction>)>[];
          for (final MoneyTransaction transaction in all) {
            final DateTime local = transaction.occurredAt.toLocal();
            final DateTime day =
                DateTime(local.year, local.month, local.day);
            if (groups.isNotEmpty && groups.last.$1 == day) {
              groups.last.$2.add(transaction);
            } else {
              groups.add((day, <MoneyTransaction>[transaction]));
            }
          }
          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: groups.length,
            itemBuilder: (BuildContext context, int index) {
              final (DateTime day, List<MoneyTransaction> items) =
                  groups[index];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (index > 0) const SizedBox(height: AppSpacing.lg),
                  Text(
                    _dayLabel(day).toUpperCase(),
                    style: moneySectionLabel(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppCard(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      children: <Widget>[
                        for (final MoneyTransaction transaction in items)
                          AppListRow(
                            title: _titleFor(transaction, categories),
                            subtitle: _accountName(transaction, accounts),
                            dense: true,
                            trailing:
                                SignedAmountText(transaction: transaction),
                            onTap: () => context.go(
                              '/money/transactions/${transaction.id}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
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
