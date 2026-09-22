import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/sync/sync_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../bills/domain/entities/bill.dart';
import '../../budgets/domain/entities/budget_entities.dart';
import '../../financial_goals/domain/entities/financial_goal.dart';
import '../../net_worth/domain/entities/net_worth.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';
import 'net_worth_screen.dart' show currentNetWorthProvider;

/// Design "Money": net worth headline, this month's flows, cash flow and
/// budget pace at a glance, upcoming bills, accounts, recent activity and
/// financial goals — everything reachable through hairline-separated
/// sections rather than nested cards.
class MoneyDashboardScreen extends ConsumerWidget {
  const MoneyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int conflictCount = ref.watch(conflictCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Money', style: lumaSerif(size: 44, height: 1.05)),
              _MoreMenu(),
            ],
          ),
          if (conflictCount > 0) ...<Widget>[
            const SizedBox(height: 20),
            _ConflictBanner(
              count: conflictCount,
              onTap: () => context.go('/money/conflicts'),
            ),
          ],
          const SizedBox(height: 28),
          const _NetWorthHeadline(),
          const SizedBox(height: 28),
          const _MonthFlows(),
          const SizedBox(height: 28),
          _CashFlowSection(),
          const SizedBox(height: 28),
          const _BudgetPaceSection(),
          const SizedBox(height: 28),
          const _UpcomingBillsSection(),
          const SizedBox(height: 28),
          LumaSectionHeader(
            'Accounts',
            action: 'See all',
            onAction: () => context.go('/money/accounts'),
          ),
          const SizedBox(height: 8),
          const _AccountsSection(),
          const SizedBox(height: 28),
          LumaSectionHeader(
            'Recent',
            action: 'See all',
            onAction: () => context.go('/money/transactions'),
          ),
          const SizedBox(height: 8),
          const _RecentTransactionsSection(),
          const SizedBox(height: 28),
          LumaSectionHeader(
            'Financial goals',
            action: 'See all',
            onAction: () => context.go('/money/financial-goals'),
          ),
          const SizedBox(height: 8),
          const _FinancialGoalsSection(),
        ],
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  static const Map<String, String> _destinations = <String, String>{
    'Add expense': '/money/add-expense',
    'Add income': '/money/add-income',
    'Budgets': '/money/budgets',
    'Savings goals': '/money/savings-goals',
    'Financial goals': '/money/financial-goals',
    'Bills': '/money/bills',
    'Subscriptions': '/money/subscriptions',
    'Debt': '/money/debts',
    'Net worth': '/money/net-worth',
    'Analytics': '/money/analytics',
  };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More',
      offset: const Offset(0, 44),
      color: LumaColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LumaRadius.surface),
        side: const BorderSide(color: LumaColors.hairline),
      ),
      onSelected: (String route) => context.go(route),
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        for (final MapEntry<String, String> entry in _destinations.entries)
          PopupMenuItem<String>(
            value: entry.value,
            height: 42,
            child: Text(entry.key, style: lumaSans(size: 14)),
          ),
      ],
      child: const SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: LumaIcon(LumaIcons.ellipsis, size: 21, color: LumaColors.ink2),
        ),
      ),
    );
  }
}

class _ConflictBanner extends StatelessWidget {
  const _ConflictBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LumaColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(LumaRadius.button),
        ),
        child: Row(
          children: <Widget>[
            const LumaIcon(LumaIcons.flag, size: 16, color: LumaColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$count transaction${count == 1 ? '' : 's'} need review',
                style: lumaSans(size: 14, weight: FontWeight.w500),
              ),
            ),
            const LumaIcon(LumaIcons.chevronRight, size: 18, color: LumaColors.ink3),
          ],
        ),
      ),
    );
  }
}

/// Big serif net worth figure, driven by the same computation as the Net
/// worth screen. Multi-currency: the profile's default currency headlines,
/// with any others listed underneath rather than merged.
class _NetWorthHeadline extends ConsumerWidget {
  const _NetWorthHeadline();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, NetWorthEntry>> current =
        ref.watch(currentNetWorthProvider);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/money/net-worth'),
      child: current.when(
        loading: () => const SizedBox(height: 96),
        error: (Object error, _) => const SizedBox.shrink(),
        data: (Map<String, NetWorthEntry> byCurrency) {
          if (byCurrency.isEmpty) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const LumaEyebrow('Net worth'),
                const SizedBox(height: 10),
                Text(
                  'Add accounts, assets, or debts to see it here.',
                  style: lumaSans(size: 14, color: LumaColors.ink3),
                ),
              ],
            );
          }
          final List<MapEntry<String, NetWorthEntry>> entries =
              byCurrency.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
          final MapEntry<String, NetWorthEntry> headline = entries.first;
          final double net = headline.value.assets - headline.value.liabilities;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const LumaEyebrow('Net worth'),
              const SizedBox(height: 10),
              Text(
                formatMoneyCompact(Money(amount: net, currency: headline.key)),
                style: lumaSerif(
                  size: LumaType.metric,
                  height: 1,
                  color: net < 0 ? LumaColors.negative : LumaColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Assets ${formatMoney(Money(amount: headline.value.assets, currency: headline.key))}'
                ' · liabilities ${formatMoney(Money(amount: headline.value.liabilities, currency: headline.key))}',
                style: lumaSans(size: 13, color: LumaColors.ink3),
              ),
              if (entries.length > 1) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  'Plus ${entries.length - 1} other currenc${entries.length - 1 == 1 ? 'y' : 'ies'}',
                  style: lumaSans(size: 12.5, color: LumaColors.ink3),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Income / expenses / saved for the current calendar month. One block per
/// currency — currencies are never summed together.
class _MonthFlows extends ConsumerWidget {
  const _MonthFlows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> month =
        ref.watch(moneyMonthTransactionsProvider);
    final String monthLabel = DateFormat('MMMM').format(DateTime.now());

    return month.when(
      loading: () => const SizedBox(height: 72),
      error: (Object error, _) => const SizedBox.shrink(),
      data: (List<MoneyTransaction> transactions) {
        if (transactions.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LumaEyebrow(monthLabel),
              const SizedBox(height: 10),
              Text('No transactions recorded yet this month.',
                  style: lumaSans(size: 14, color: LumaColors.ink3)),
            ],
          );
        }
        final Map<String, ({double income, double expense})> byCurrency =
            <String, ({double income, double expense})>{};
        for (final MoneyTransaction t in transactions) {
          final ({double income, double expense}) cur =
              byCurrency[t.amount.currency] ?? (income: 0, expense: 0);
          byCurrency[t.amount.currency] = switch (t.kind) {
            TransactionKind.income =>
              (income: cur.income + t.amount.amount, expense: cur.expense),
            TransactionKind.expense =>
              (income: cur.income, expense: cur.expense + t.amount.amount),
            TransactionKind.transfer => cur,
          };
        }
        final List<String> currencies = byCurrency.keys.toList()..sort();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            LumaEyebrow(monthLabel),
            const SizedBox(height: 14),
            for (int i = 0; i < currencies.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 18),
              _MonthCurrencyRow(
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

class _MonthCurrencyRow extends StatelessWidget {
  const _MonthCurrencyRow({
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
    final double? savingsRate = income > 0 ? saved / income : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
                child: _FlowStat(
                    label: 'Income',
                    value: Money(amount: income, currency: currency),
                    color: LumaColors.positive)),
            Expanded(
                child: _FlowStat(
                    label: 'Spent',
                    value: Money(amount: expense, currency: currency),
                    color: LumaColors.negative)),
            Expanded(
                child: _FlowStat(
                    label: 'Saved',
                    value: Money(amount: saved, currency: currency))),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          savingsRate == null
              ? '$currency · no income recorded yet'
              : '$currency · saving ${(savingsRate * 100).round()}% of income',
          style: lumaSans(size: 12.5, color: LumaColors.ink3),
        ),
      ],
    );
  }
}

class _FlowStat extends StatelessWidget {
  const _FlowStat({required this.label, required this.value, this.color});

  final String label;
  final Money value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
        const SizedBox(height: 4),
        Text(
          formatMoneyCompact(value),
          style: lumaSans(
              size: 17, weight: FontWeight.w500, color: color ?? LumaColors.ink),
        ),
      ],
    );
  }
}

/// Two hairline-track bars comparing this month's income and spend — a
/// lightweight cash-flow glance; the full six-month chart lives in Analytics.
class _CashFlowSection extends ConsumerWidget {
  const _CashFlowSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> month =
        ref.watch(moneyMonthTransactionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LumaSectionHeader(
          'Cash flow',
          action: 'Details',
          onAction: () => context.go('/money/analytics'),
        ),
        const SizedBox(height: 14),
        month.when(
          loading: () => const SizedBox(height: 40),
          error: (Object error, _) => const SizedBox.shrink(),
          data: (List<MoneyTransaction> transactions) {
            if (transactions.isEmpty) {
              return Text('Nothing to chart yet this month.',
                  style: lumaSans(size: 13, color: LumaColors.ink3));
            }
            final Map<String, int> counts = <String, int>{};
            for (final MoneyTransaction t in transactions) {
              counts.update(t.amount.currency, (int v) => v + 1, ifAbsent: () => 1);
            }
            final String currency = counts.entries
                .reduce((a, b) => a.value >= b.value ? a : b)
                .key;
            double income = 0;
            double expense = 0;
            for (final MoneyTransaction t in transactions) {
              if (t.amount.currency != currency) continue;
              if (t.kind == TransactionKind.income) income += t.amount.amount;
              if (t.kind == TransactionKind.expense) expense += t.amount.amount;
            }
            final double max = income > expense ? income : expense;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _CashFlowBar(
                  label: 'Income',
                  value: Money(amount: income, currency: currency),
                  fraction: max <= 0 ? 0 : income / max,
                  color: LumaColors.positive,
                ),
                const SizedBox(height: 10),
                _CashFlowBar(
                  label: 'Expenses',
                  value: Money(amount: expense, currency: currency),
                  fraction: max <= 0 ? 0 : expense / max,
                  color: LumaColors.negative,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CashFlowBar extends StatelessWidget {
  const _CashFlowBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  final String label;
  final Money value;
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
            width: 64,
            child: Text(label, style: lumaSans(size: 12.5, color: LumaColors.ink3))),
        Expanded(
          child: LumaProgressLine(value: fraction, color: color, height: 8),
        ),
        const SizedBox(width: 10),
        Text(formatMoneyCompact(value),
            style: lumaSans(size: 13, weight: FontWeight.w500)),
      ],
    );
  }
}

/// Pace against the most recently created budget, if any.
class _BudgetPaceSection extends ConsumerWidget {
  const _BudgetPaceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Budget> budgets = ref.watch(moneyBudgetsProvider).value ?? const <Budget>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LumaSectionHeader(
          'Budget',
          action: 'View all',
          onAction: () => context.go('/money/budgets'),
        ),
        const SizedBox(height: 14),
        if (budgets.isEmpty)
          GestureDetector(
            onTap: () => context.go('/money/budgets'),
            child: Text('Set up a budget to track your pace.',
                style: lumaSans(size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
          )
        else
          _BudgetPaceRow(budget: budgets.first),
      ],
    );
  }
}

class _BudgetPaceRow extends ConsumerWidget {
  const _BudgetPaceRow({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BudgetPace> pace = ref.watch(moneyBudgetPaceProvider(budget.id));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/money/budgets/${budget.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(budget.name, style: lumaSans(size: 15, weight: FontWeight.w500)),
          const SizedBox(height: 8),
          pace.when(
            loading: () => const LumaProgressLine(value: 0, height: 6),
            error: (Object error, _) => const SizedBox.shrink(),
            data: (BudgetPace p) {
              final double fraction = p.planned <= 0 ? 0 : (p.actual / p.planned).clamp(0.0, 1.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LumaProgressLine(
                    value: fraction,
                    height: 6,
                    color: p.actual > p.planned ? LumaColors.warning : LumaColors.accent,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.planned <= 0
                        ? 'No categories budgeted yet.'
                        : '${formatMoney(Money(amount: p.actual, currency: p.currency))} of '
                            '${formatMoney(Money(amount: p.planned, currency: p.currency))} this period',
                    style: lumaSans(size: 12.5, color: LumaColors.ink3),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _UpcomingBillsSection extends ConsumerWidget {
  const _UpcomingBillsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Bill>> bills = ref.watch(moneyUpcomingBillsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LumaSectionHeader(
          'Upcoming',
          action: 'See all',
          onAction: () => context.go('/money/bills'),
        ),
        bills.when(
          loading: () => const SizedBox(height: 40),
          error: (Object error, _) => const SizedBox.shrink(),
          data: (List<Bill> all) {
            if (all.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('No bills due soon.',
                    style: lumaSans(size: 14, color: LumaColors.ink3)),
              );
            }
            return Column(
              children: <Widget>[
                for (final Bill bill in all)
                  LumaMetaRow(
                    label: bill.name,
                    value:
                        '${formatMoney(bill.amount)} · ${DateFormat('MMM d').format(bill.dueDate.toLocal())}',
                    onTap: () => context.go('/money/bills'),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AccountsSection extends ConsumerWidget {
  const _AccountsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialAccount>> accounts = ref.watch(moneyAccountsProvider);

    return accounts.when(
      loading: () => const SizedBox(height: 48),
      error: (Object error, _) => const SizedBox.shrink(),
      data: (List<FinancialAccount> all) {
        if (all.isEmpty) {
          return GestureDetector(
            onTap: () => context.go('/money/accounts'),
            child: Text('No accounts yet — add one to start tracking.',
                style: lumaSans(size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
          );
        }
        return Column(
          children: <Widget>[
            for (final FinancialAccount account in all) _AccountRow(account: account),
          ],
        );
      },
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account});

  final FinancialAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> balance = ref.watch(moneyAccountBalanceProvider(account.id));

    return LumaMetaRow(
      label: account.name,
      value: balance.value == null ? '…' : formatMoney(balance.value!),
      onTap: () => context.go('/money/accounts/${account.id}'),
    );
  }
}

class _RecentTransactionsSection extends ConsumerWidget {
  const _RecentTransactionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(moneyRecentTransactionsProvider);
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];

    return transactions.when(
      loading: () => const SizedBox(height: 96),
      error: (Object error, _) => const SizedBox.shrink(),
      data: (List<MoneyTransaction> recent) {
        if (recent.isEmpty) {
          return GestureDetector(
            onTap: () => context.go('/money/add-expense'),
            child: Text('No transactions yet — add your first expense.',
                style: lumaSans(size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
          );
        }
        return Column(
          children: <Widget>[
            for (final MoneyTransaction transaction in recent)
              _RecentTransactionRow(transaction: transaction, categories: categories),
          ],
        );
      },
    );
  }
}

class _RecentTransactionRow extends StatelessWidget {
  const _RecentTransactionRow({required this.transaction, required this.categories});

  final MoneyTransaction transaction;
  final List<TransactionCategory> categories;

  String get _title {
    for (final TransactionCategory category in categories) {
      if (category.id == transaction.categoryId) return category.name;
    }
    final String? note = transaction.note;
    if (note != null && note.isNotEmpty) return note;
    return transactionKindLabel(transaction.kind);
  }

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
            MoneyLetterAvatar(label: _title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(_title,
                      style: lumaSans(size: 14.5, weight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(DateFormat.MMMd().format(transaction.occurredAt.toLocal()),
                      style: lumaSans(size: 12.5, color: LumaColors.ink3)),
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

class _FinancialGoalsSection extends ConsumerWidget {
  const _FinancialGoalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialGoal>> goals = ref.watch(moneyFinancialGoalsProvider);

    return goals.when(
      loading: () => const SizedBox(height: 48),
      error: (Object error, _) => const SizedBox.shrink(),
      data: (List<FinancialGoal> all) {
        if (all.isEmpty) {
          return GestureDetector(
            onTap: () => context.go('/money/financial-goals'),
            child: Text('No financial goals yet — give your money a direction.',
                style: lumaSans(size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
          );
        }
        return Column(
          children: <Widget>[
            for (final FinancialGoal goal in all)
              LumaMetaRow(
                label: goal.name,
                value: goal.targetAmount == null ? '—' : formatMoney(goal.targetAmount!),
                onTap: () => context.go('/money/financial-goals'),
              ),
          ],
        );
      },
    );
  }
}
