import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../financial_goals/domain/entities/financial_goal.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Money command center: this month's flows per currency, account balances,
/// recent transactions, and financial goals — all from local Drift streams.
class MoneyDashboardScreen extends ConsumerWidget {
  const MoneyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int conflictCount = ref.watch(conflictCountProvider).value ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Money'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Accounts',
            icon: const Icon(Icons.account_balance_outlined),
            onPressed: () => context.go('/money/accounts'),
          ),
          IconButton(
            tooltip: 'Budgets',
            icon: const Icon(Icons.pie_chart_outline),
            onPressed: () => context.go('/money/budgets'),
          ),
          IconButton(
            tooltip: 'Analytics',
            icon: const Icon(Icons.query_stats),
            onPressed: () => context.go('/money/analytics'),
          ),
          PopupMenuButton<String>(
            tooltip: 'More money features',
            icon: const Icon(Icons.more_vert),
            onSelected: (String route) => context.go(route),
            itemBuilder: (BuildContext context) =>
                const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: '/money/savings-goals',
                child: Text('Savings goals'),
              ),
              PopupMenuItem<String>(
                value: '/money/financial-goals',
                child: Text('Financial goals'),
              ),
              PopupMenuItem<String>(
                value: '/money/bills',
                child: Text('Bills'),
              ),
              PopupMenuItem<String>(
                value: '/money/subscriptions',
                child: Text('Subscriptions'),
              ),
              PopupMenuItem<String>(
                value: '/money/debts',
                child: Text('Debt'),
              ),
              PopupMenuItem<String>(
                value: '/money/net-worth',
                child: Text('Net worth'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (conflictCount > 0)
            ConflictBanner(
              count: conflictCount,
              onTap: () => context.go('/money/conflicts'),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.huge,
              ),
              children: <Widget>[
                Text(
                  DateFormat('MMMM yyyy').format(DateTime.now()).toUpperCase(),
                  style: moneySectionLabel(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _MonthSummary(),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: AppButton(
                        label: 'Add expense',
                        icon: Icons.remove_circle_outline,
                        onPressed: () => context.go('/money/add-expense'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppButton(
                        label: 'Add income',
                        icon: Icons.add_circle_outline,
                        variant: AppButtonVariant.secondary,
                        onPressed: () => context.go('/money/add-income'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  label: 'ACCOUNTS',
                  onSeeAll: () => context.go('/money/accounts'),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _AccountsSummary(),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  label: 'RECENT TRANSACTIONS',
                  onSeeAll: () => context.go('/money/transactions'),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _RecentTransactions(),
                const SizedBox(height: AppSpacing.xl),
                _SectionHeader(
                  label: 'FINANCIAL GOALS',
                  onSeeAll: () => context.go('/money/financial-goals'),
                ),
                const SizedBox(height: AppSpacing.sm),
                const _FinancialGoals(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.onSeeAll});

  final String label;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: moneySectionLabel(context)),
        TextButton(onPressed: onSeeAll, child: const Text('See all')),
      ],
    );
  }
}

/// Per-currency income/expenses/saved/savings-rate for the current month.
/// Currencies are never mixed: each currency gets its own card.
class _MonthSummary extends ConsumerWidget {
  const _MonthSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> month =
        ref.watch(moneyMonthTransactionsProvider);

    return month.when(
      loading: () => const LoadingShimmer(height: 120),
      error: (Object error, _) =>
          ErrorStateView(message: "Could not load this month's activity."),
      data: (List<MoneyTransaction> transactions) {
        if (transactions.isEmpty) {
          return const AppCard(
            child: Text('No transactions recorded this month yet.'),
          );
        }
        final Map<String, ({double income, double expense})> byCurrency =
            <String, ({double income, double expense})>{};
        for (final MoneyTransaction transaction in transactions) {
          final String currency = transaction.amount.currency;
          final ({double income, double expense}) current =
              byCurrency[currency] ?? (income: 0, expense: 0);
          byCurrency[currency] = switch (transaction.kind) {
            TransactionKind.income => (
                income: current.income + transaction.amount.amount,
                expense: current.expense,
              ),
            TransactionKind.expense => (
                income: current.income,
                expense: current.expense + transaction.amount.amount,
              ),
            TransactionKind.transfer => current,
          };
        }
        final List<String> currencies = byCurrency.keys.toList()..sort();
        return Column(
          children: <Widget>[
            for (int i = 0; i < currencies.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _MonthCurrencyCard(
                currency: currencies[i],
                income: byCurrency[currencies[i]]!.income,
                expense: byCurrency[currencies[i]]!.expense,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _MonthCurrencyCard extends StatelessWidget {
  const _MonthCurrencyCard({
    required this.currency,
    required this.income,
    required this.expense,
  });

  final String currency;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    final double saved = income - expense;
    // Only computed from recorded data; undefined when no income recorded.
    final double? savingsRate = income > 0 ? saved / income : null;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            currency,
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: _MonthStat(
                  label: 'Income',
                  value:
                      formatMoney(Money(amount: income, currency: currency)),
                  color: context.semanticColors.income,
                ),
              ),
              Expanded(
                child: _MonthStat(
                  label: 'Expenses',
                  value:
                      formatMoney(Money(amount: expense, currency: currency)),
                  color: context.semanticColors.expense,
                ),
              ),
              Expanded(
                child: _MonthStat(
                  label: 'Saved',
                  value: formatMoney(Money(amount: saved, currency: currency)),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            savingsRate == null
                ? 'Savings rate: no income recorded this month'
                : 'Savings rate: ${(savingsRate * 100).toStringAsFixed(0)}% of recorded income',
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AppTypography.currencyMedium.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _AccountsSummary extends ConsumerWidget {
  const _AccountsSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialAccount>> accounts =
        ref.watch(moneyAccountsProvider);

    return accounts.when(
      loading: () => const LoadingShimmer(height: 96),
      error: (Object error, _) =>
          ErrorStateView(message: 'Could not load accounts.'),
      data: (List<FinancialAccount> all) {
        if (all.isEmpty) {
          return EmptyStateView(
            message: 'No accounts yet — add one to start tracking.',
            icon: Icons.account_balance_outlined,
            ctaLabel: 'Manage accounts',
            onCta: () => context.go('/money/accounts'),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (final FinancialAccount account in all)
                _AccountBalanceRow(account: account),
            ],
          ),
        );
      },
    );
  }
}

class _AccountBalanceRow extends ConsumerWidget {
  const _AccountBalanceRow({required this.account});

  final FinancialAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> balance =
        ref.watch(moneyAccountBalanceProvider(account.id));

    return AppListRow(
      title: account.name,
      subtitle: accountTypeLabel(account.type),
      dense: true,
      trailing: Text(
        balance.value == null ? '…' : formatMoney(balance.value!),
        style: AppTypography.currencyMedium,
      ),
      onTap: () => context.go('/money/accounts/${account.id}'),
    );
  }
}

class _RecentTransactions extends ConsumerWidget {
  const _RecentTransactions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(moneyRecentTransactionsProvider);
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];

    return transactions.when(
      loading: () => const LoadingShimmer(height: 160),
      error: (Object error, _) =>
          ErrorStateView(message: 'Could not load transactions.'),
      data: (List<MoneyTransaction> recent) {
        if (recent.isEmpty) {
          return EmptyStateView(
            message: 'No transactions yet — add your first expense.',
            icon: Icons.receipt_long_outlined,
            ctaLabel: 'Add expense',
            onCta: () => context.go('/money/add-expense'),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (final MoneyTransaction transaction in recent)
                AppListRow(
                  title: _titleFor(transaction, categories),
                  subtitle: DateFormat.MMMd()
                      .format(transaction.occurredAt.toLocal()),
                  dense: true,
                  trailing: SignedAmountText(transaction: transaction),
                  onTap: () =>
                      context.go('/money/transactions/${transaction.id}'),
                ),
            ],
          ),
        );
      },
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

class _FinancialGoals extends ConsumerWidget {
  const _FinancialGoals();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialGoal>> goals =
        ref.watch(moneyFinancialGoalsProvider);

    return goals.when(
      loading: () => const LoadingShimmer(height: 72),
      error: (Object error, _) =>
          ErrorStateView(message: 'Could not load financial goals.'),
      data: (List<FinancialGoal> all) {
        if (all.isEmpty) {
          return EmptyStateView(
            message: 'No financial goals yet.',
            icon: Icons.flag_outlined,
            ctaLabel: 'Create one',
            onCta: () => context.go('/money/financial-goals'),
          );
        }
        return AppCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            children: <Widget>[
              for (final FinancialGoal goal in all)
                AppListRow(
                  title: goal.name,
                  subtitle: goal.targetDate == null
                      ? null
                      : 'Target ${DateFormat.yMMMd().format(goal.targetDate!)}',
                  dense: true,
                  trailing: goal.targetAmount == null
                      ? null
                      : Text(
                          formatMoney(goal.targetAmount!),
                          style: AppTypography.currencyMedium,
                        ),
                  onTap: () => context.go('/money/financial-goals'),
                ),
            ],
          ),
        );
      },
    );
  }
}
