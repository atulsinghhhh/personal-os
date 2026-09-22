import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
import '../../../../shared/models/money.dart';
import '../../../ai/data/ai_planning_service.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../widgets/money_ui.dart';

/// Last six full months of transactions, oldest first.
final StreamProvider<List<MoneyTransaction>> _sixMonthsProvider =
    StreamProvider<List<MoneyTransaction>>((Ref ref) {
  final DateTime now = DateTime.now();
  final DateTime start = DateTime.utc(now.year, now.month - 5);
  final DateTime end = DateTime.utc(now.year, now.month + 1);
  return ref.watch(transactionRepositoryProvider).watchForRange(start, end);
});

final StreamProvider<List<TransactionCategory>> _categoriesProvider =
    StreamProvider<List<TransactionCategory>>((Ref ref) {
  return ref.watch(transactionCategoryRepositoryProvider).watchAll();
});

/// Design "CashFlow": a six-month income/expense bar chart, spend by
/// category this month, and opt-in AI insights over the user's own numbers.
class MoneyAnalyticsScreen extends ConsumerWidget {
  const MoneyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> transactions = ref.watch(_sixMonthsProvider);
    final List<TransactionCategory> categories =
        ref.watch(_categoriesProvider).value ?? <TransactionCategory>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Text('Cash flow', style: lumaSerif(size: 40, height: 1.05)),
          const SizedBox(height: 28),
          transactions.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load transactions.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<MoneyTransaction> all) {
              if (all.isEmpty) {
                return Text('Record income and expenses to see analytics.',
                    style: lumaSans(size: 14, color: LumaColors.ink3));
              }

              final Map<String, int> currencyCounts = <String, int>{};
              for (final MoneyTransaction t in all) {
                currencyCounts.update(t.amount.currency, (int v) => v + 1, ifAbsent: () => 1);
              }
              final String currency =
                  currencyCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
              final List<MoneyTransaction> inCurrency =
                  all.where((MoneyTransaction t) => t.amount.currency == currency).toList();

              final DateTime now = DateTime.now();
              final List<DateTime> months = <DateTime>[
                for (int i = 5; i >= 0; i--) DateTime.utc(now.year, now.month - i),
              ];
              final List<double> incomeByMonth = <double>[];
              final List<double> expenseByMonth = <double>[];
              final List<String> labels = <String>[];
              for (final DateTime month in months) {
                final DateTime next = DateTime.utc(month.year, month.month + 1);
                double income = 0;
                double expense = 0;
                for (final MoneyTransaction t in inCurrency) {
                  if (t.occurredAt.isBefore(month) || !t.occurredAt.isBefore(next)) continue;
                  if (t.kind == TransactionKind.income) income += t.amount.amount;
                  if (t.kind == TransactionKind.expense) expense += t.amount.amount;
                }
                incomeByMonth.add(income);
                expenseByMonth.add(expense);
                labels.add(DateFormat.MMM().format(month));
              }

              final DateTime monthStart = DateTime.utc(now.year, now.month);
              final Map<String, double> byCategory = <String, double>{};
              for (final MoneyTransaction t in inCurrency) {
                if (t.kind != TransactionKind.expense || t.occurredAt.isBefore(monthStart)) {
                  continue;
                }
                final String name = categories
                        .where((TransactionCategory c) => c.id == t.categoryId)
                        .map((TransactionCategory c) => c.name)
                        .firstOrNull ??
                    'Uncategorized';
                byCategory.update(name, (double v) => v + t.amount.amount,
                    ifAbsent: () => t.amount.amount);
              }
              final List<MapEntry<String, double>> topCategories = byCategory.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final double monthExpenseTotal =
                  byCategory.values.fold<double>(0, (double a, double b) => a + b);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  LumaEyebrow('Last 6 months · $currency'),
                  const SizedBox(height: 16),
                  _SixMonthChart(income: incomeByMonth, expense: expenseByMonth, labels: labels),
                  const SizedBox(height: 8),
                  Text(
                    'Only $currency transactions are charted (your most-used currency).',
                    style: lumaSans(size: 12.5, color: LumaColors.ink3),
                  ),
                  const SizedBox(height: 28),
                  LumaSectionHeader('This month by category'),
                  const SizedBox(height: 14),
                  if (topCategories.isEmpty)
                    Text('No expenses this month.',
                        style: lumaSans(size: 14, color: LumaColors.ink3))
                  else
                    Column(
                      children: <Widget>[
                        for (final MapEntry<String, double> entry in topCategories.take(8))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                        child: Text(entry.key,
                                            style: lumaSans(size: 14.5, weight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis)),
                                    Text(
                                        formatMoney(
                                            Money(amount: entry.value, currency: currency)),
                                        style: lumaSans(size: 14, weight: FontWeight.w500)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                LumaProgressLine(
                                  value: monthExpenseTotal <= 0
                                      ? 0
                                      : entry.value / monthExpenseTotal,
                                  height: 5,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  const SizedBox(height: 14),
                  LumaSectionHeader('AI insights'),
                  const SizedBox(height: 14),
                  _AiInsightsSection(
                    currency: currency,
                    thisMonthExpense: expenseByMonth.isEmpty ? 0 : expenseByMonth.last,
                    lastMonthExpense:
                        expenseByMonth.length < 2 ? 0 : expenseByMonth[expenseByMonth.length - 2],
                    thisMonthIncome: incomeByMonth.isEmpty ? 0 : incomeByMonth.last,
                    topCategories: topCategories,
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

class _SixMonthChart extends StatelessWidget {
  const _SixMonthChart({required this.income, required this.expense, required this.labels});

  final List<double> income;
  final List<double> expense;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final double max = <double>[...income, ...expense].fold<double>(
        0, (double a, double b) => b > a ? b : a);

    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          for (int i = 0; i < labels.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        _Bar(
                          height: max <= 0 ? 0 : 100 * income[i] / max,
                          color: LumaColors.positive,
                        ),
                        const SizedBox(width: 3),
                        _Bar(
                          height: max <= 0 ? 0 : 100 * expense[i] / max,
                          color: LumaColors.negative,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(labels[i], style: lumaSans(size: 11, color: LumaColors.ink3)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.height, required this.color});

  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: height.clamp(2, 100),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// AI explains the user's own recorded numbers (never advice, never
/// fabricated figures — see supabase/functions/ai-plan). Opt-in via button.
class _AiInsightsSection extends ConsumerStatefulWidget {
  const _AiInsightsSection({
    required this.currency,
    required this.thisMonthExpense,
    required this.lastMonthExpense,
    required this.thisMonthIncome,
    required this.topCategories,
  });

  final String currency;
  final double thisMonthExpense;
  final double lastMonthExpense;
  final double thisMonthIncome;
  final List<MapEntry<String, double>> topCategories;

  @override
  ConsumerState<_AiInsightsSection> createState() => _AiInsightsSectionState();
}

class _AiInsightsSectionState extends ConsumerState<_AiInsightsSection> {
  bool _loading = false;
  List<dynamic>? _insights;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _error = null;
      _insights = null;
    });

    final Map<String, dynamic> context = <String, dynamic>{
      'currency': widget.currency,
      'this_month_expense': widget.thisMonthExpense,
      'last_month_expense': widget.lastMonthExpense,
      'this_month_income': widget.thisMonthIncome,
      'top_categories_this_month': <Map<String, dynamic>>[
        for (final MapEntry<String, double> entry in widget.topCategories.take(5))
          <String, dynamic>{'category': entry.key, 'amount': entry.value},
      ],
    };

    final AiPlanResult result =
        await ref.read(aiPlanningServiceProvider).propose(mode: 'financial', context: context);

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isOk) {
        _insights = result.proposal!['insights'] as List<dynamic>?;
      } else {
        _error = result.errorMessage;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          "Have the assistant explain this month's numbers — it only restates "
          'and does arithmetic on your recorded data, never advice.',
          style: lumaSans(size: 14, color: LumaColors.ink2),
        ),
        const SizedBox(height: 14),
        LumaSecondaryButton(
          label: _loading ? 'Thinking…' : 'Explain my spending',
          onTap: _loading ? null : _generate,
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 14),
          Text(_error!, style: lumaSans(size: 13, color: LumaColors.warning)),
        ],
        if (_insights != null) ...<Widget>[
          const SizedBox(height: 14),
          for (final dynamic insight in _insights!)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(((insight as Map)['title'] as String?) ?? '',
                      style: lumaSans(size: 15, weight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text((insight['detail'] as String?) ?? '',
                      style: lumaSans(size: 13.5, color: LumaColors.ink2)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
