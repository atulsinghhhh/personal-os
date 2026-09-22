import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FinancialAccount?> account =
        ref.watch(moneyAccountByIdProvider(accountId));
    final AsyncValue<Money> balance =
        ref.watch(moneyAccountBalanceProvider(accountId));
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(moneyAccountTransactionsProvider(accountId));
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];

    return Scaffold(
      appBar: AppBar(title: Text(account.value?.name ?? 'Account')),
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load this account.'),
        data: (FinancialAccount? data) {
          if (data == null) {
            return const EmptyStateView(message: 'Account not found.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      accountTypeLabel(data.type).toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      balance.value == null
                          ? '…'
                          : formatMoney(balance.value!),
                      style: AppTypography.currencyLarge,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Opening balance: ${formatMoney(data.openingBalance)}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('TRANSACTIONS', style: moneySectionLabel(context)),
              const SizedBox(height: AppSpacing.sm),
              transactions.when(
                loading: () => const LoadingShimmer(height: 160),
                error: (Object error, _) =>
                    ErrorStateView(message: 'Could not load transactions.'),
                data: (List<MoneyTransaction> all) {
                  if (all.isEmpty) {
                    return const EmptyStateView(
                      message: 'No transactions on this account yet.',
                      icon: Icons.receipt_long_outlined,
                    );
                  }
                  return AppCard(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      children: <Widget>[
                        for (final MoneyTransaction transaction in all)
                          AppListRow(
                            title: _titleFor(transaction, categories),
                            subtitle: DateFormat.yMMMd()
                                .format(transaction.occurredAt.toLocal()),
                            dense: true,
                            trailing:
                                SignedAmountText(transaction: transaction),
                            onTap: () => context.go(
                              '/money/transactions/${transaction.id}',
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
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
}
