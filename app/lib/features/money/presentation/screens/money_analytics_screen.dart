import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_chart.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
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
  return ref
      .watch(transactionRepositoryProvider)
      .watchForRange(start, end);
});

final StreamProvider<List<TransactionCategory>> _categoriesProvider =
    StreamProvider<List<TransactionCategory>>((Ref ref) {
  return ref.watch(transactionCategoryRepositoryProvider).watchAll();
});

/// Spending analytics over the user's recorded data. Every figure is plain
/// arithmetic on transactions; the dominant currency (most transactions)
/// is charted and the caption says so — currencies are never merged.
class MoneyAnalyticsScreen extends ConsumerWidget {
  const MoneyAnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(_sixMonthsProvider);
    final List<TransactionCategory> categories =
        ref.watch(_categoriesProvider).value ?? <TransactionCategory>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Money analytics')),
      body: transactions.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LoadingShimmer(height: 160),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load transactions.'),
        data: (List<MoneyTransaction> all) {
          if (all.isEmpty) {
            return const EmptyStateView(
              message: 'Record income and expenses to see analytics.',
              icon: Icons.query_stats,
            );
          }

          // Dominant currency by transaction count.
          final Map<String, int> currencyCounts = <String, int>{};
          for (final MoneyTransaction t in all) {
            currencyCounts.update(
              t.amount.currency,
              (int v) => v + 1,
              ifAbsent: () => 1,
            );
          }
          final String currency = currencyCounts.entries
              .reduce(
                (MapEntry<String, int> a, MapEntry<String, int> b) =>
                    a.value >= b.value ? a : b,
              )
              .key;
          final List<MoneyTransaction> inCurrency = all
              .where((MoneyTransaction t) => t.amount.currency == currency)
              .toList(growable: false);

          // Per-month income/expense for the last 6 months.
          final DateTime now = DateTime.now();
          final List<DateTime> months = <DateTime>[
            for (int i = 5; i >= 0; i--)
              DateTime.utc(now.year, now.month - i),
          ];
          final List<double> incomeByMonth = <double>[];
          final List<double> expenseByMonth = <double>[];
          final List<String> labels = <String>[];
          for (final DateTime month in months) {
            final DateTime next = DateTime.utc(month.year, month.month + 1);
            double income = 0;
            double expense = 0;
            for (final MoneyTransaction t in inCurrency) {
              if (t.occurredAt.isBefore(month) ||
                  !t.occurredAt.isBefore(next)) {
                continue;
              }
              if (t.kind == TransactionKind.income) income += t.amount.amount;
              if (t.kind == TransactionKind.expense) {
                expense += t.amount.amount;
              }
            }
            incomeByMonth.add(income);
            expenseByMonth.add(expense);
            labels.add(DateFormat.MMM().format(month));
          }

          // Spending by category, current month.
          final DateTime monthStart = DateTime.utc(now.year, now.month);
          final Map<String, double> byCategory = <String, double>{};
          for (final MoneyTransaction t in inCurrency) {
            if (t.kind != TransactionKind.expense ||
                t.occurredAt.isBefore(monthStart)) {
              continue;
            }
            final String name = categories
                .where((TransactionCategory c) => c.id == t.categoryId)
                .map((TransactionCategory c) => c.name)
                .firstOrNull ??
                'Uncategorized';
            byCategory.update(
              name,
              (double v) => v + t.amount.amount,
              ifAbsent: () => t.amount.amount,
            );
          }
          final List<MapEntry<String, double>> topCategories =
              byCategory.entries.toList()
                ..sort(
                  (MapEntry<String, double> a, MapEntry<String, double> b) =>
                      b.value.compareTo(a.value),
                );
          final double monthExpenseTotal = byCategory.values
              .fold<double>(0, (double a, double b) => a + b);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Text(
                'INCOME VS EXPENSES ($currency, LAST 6 MONTHS)',
                style: _label(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('Income', style: AppTypography.labelSmall),
                    AppBarChart(values: incomeByMonth, labels: labels),
                    const SizedBox(height: AppSpacing.md),
                    Text('Expenses', style: AppTypography.labelSmall),
                    AppBarChart(
                      values: expenseByMonth,
                      labels: labels,
                      color: context.semanticColors.expense,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'THIS MONTH BY CATEGORY ($currency)',
                style: _label(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (topCategories.isEmpty)
                const AppCard(child: Text('No expenses this month.'))
              else
                AppCard(
                  child: Column(
                    children: <Widget>[
                      for (final MapEntry<String, double> entry
                          in topCategories.take(8)) ...<Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                entry.key,
                                style: AppTypography.bodyMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              formatMoney(
                                Money(
                                  amount: entry.value,
                                  currency: currency,
                                ),
                              ),
                              style: AppTypography.labelLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        LinearProgressIndicator(
                          value: monthExpenseTotal <= 0
                              ? 0
                              : entry.value / monthExpenseTotal,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Only $currency transactions are charted (your most-used '
                'currency). All figures are sums of your recorded '
                'transactions.',
                style: AppTypography.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('AI INSIGHTS', style: _label(context)),
              const SizedBox(height: AppSpacing.sm),
              _AiInsightsSection(
                currency: currency,
                thisMonthExpense:
                    expenseByMonth.isEmpty ? 0 : expenseByMonth.last,
                lastMonthExpense: expenseByMonth.length < 2
                    ? 0
                    : expenseByMonth[expenseByMonth.length - 2],
                thisMonthIncome:
                    incomeByMonth.isEmpty ? 0 : incomeByMonth.last,
                topCategories: topCategories,
              ),
            ],
          );
        },
      ),
    );
  }

  static TextStyle _label(BuildContext context) =>
      AppTypography.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      );
}

/// AI explains the user's own recorded numbers (never advice, never
/// fabricated figures — see supabase/functions/ai-plan). Opt-in via button,
/// same pattern as AI planning: nothing happens until the user asks.
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
  ConsumerState<_AiInsightsSection> createState() =>
      _AiInsightsSectionState();
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
        for (final MapEntry<String, double> entry
            in widget.topCategories.take(5))
          <String, dynamic>{'category': entry.key, 'amount': entry.value},
      ],
    };

    final AiPlanResult result = await ref
        .read(aiPlanningServiceProvider)
        .propose(mode: 'financial', context: context);

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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Have the assistant explain this month\'s numbers — it only '
            'restates and does arithmetic on your recorded data, never '
            'advice.',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: _loading ? 'Thinking…' : 'Explain my spending',
            variant: AppButtonVariant.secondary,
            onPressed: _loading ? null : _generate,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              _error!,
              style: AppTypography.bodyMedium.copyWith(
                color: context.semanticColors.warning,
              ),
            ),
          ],
          if (_insights != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            for (final dynamic insight in _insights!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      ((insight as Map)['title'] as String?) ?? '',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      (insight['detail'] as String?) ?? '',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
