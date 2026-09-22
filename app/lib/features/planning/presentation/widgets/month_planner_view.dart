import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../domain/entities/plan_entities.dart';
import '../providers/plan_providers.dart';
import 'planner_widgets.dart';

/// Month view: a theme, goals due inside the month, and money in/out per
/// currency (never summed across currencies).
class MonthPlannerView extends ConsumerStatefulWidget {
  const MonthPlannerView({super.key});

  @override
  ConsumerState<MonthPlannerView> createState() => _MonthPlannerViewState();
}

class _MonthPlannerViewState extends ConsumerState<MonthPlannerView> {
  DateTime _month = DateTime.utc(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final DateTime nextMonth =
        DateTime.utc(_month.year, _month.month + 1);
    final AsyncValue<MonthlyPlan?> plan =
        ref.watch(monthlyPlanForMonthProvider(_month));
    final AsyncValue<List<Goal>> goals = ref.watch(allGoalsProvider);
    final AsyncValue<List<MoneyTransaction>> transactions = ref.watch(
      transactionsForRangeProvider((start: _month, end: nextMonth)),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        PlannerNavHeader(
          label: DateFormat('MMMM yyyy').format(_month),
          onPrevious: () => setState(
            () => _month = DateTime.utc(_month.year, _month.month - 1),
          ),
          onNext: () => setState(
            () => _month = DateTime.utc(_month.year, _month.month + 1),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('THEME', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        plan.when(
          loading: () => const LoadingShimmer(height: 120),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the month plan.'),
          data: (MonthlyPlan? existing) => PlanTextFieldCard(
            key: ValueKey<String>('month-$_month-${existing?.id}'),
            label: 'Theme for the month',
            hint: 'e.g. Ship, then rest',
            initialValue: existing?.theme,
            onSave: (String value) => _saveTheme(existing, value),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('DUE THIS MONTH', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        goals.when(
          loading: () => const LoadingShimmer(height: 120),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load goals.'),
          data: (List<Goal> all) => _DueGoalsList(all: all, month: _month),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('MONEY THIS MONTH', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        transactions.when(
          loading: () => const LoadingShimmer(height: 100),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load transactions.'),
          data: (List<MoneyTransaction> all) => _MoneySummary(all: all),
        ),
      ],
    );
  }

  Future<void> _saveTheme(MonthlyPlan? existing, String value) async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final DateTime now = DateTime.now().toUtc();
    await ref.read(monthlyPlanRepositoryProvider).upsert(
          MonthlyPlan(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            month: _month,
            theme: value.isEmpty ? null : value,
            goalIds: existing?.goalIds ?? const <String>[],
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }
}

class _DueGoalsList extends StatelessWidget {
  const _DueGoalsList({required this.all, required this.month});

  final List<Goal> all;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final List<Goal> due = <Goal>[
      for (final Goal goal in all)
        if (goal.targetDate != null &&
            goal.targetDate!.year == month.year &&
            goal.targetDate!.month == month.month)
          goal,
    ]..sort(
        (Goal a, Goal b) => a.targetDate!.compareTo(b.targetDate!),
      );

    if (due.isEmpty) {
      return const AppCard(child: Text('No goals due this month.'));
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          for (final Goal goal in due)
            AppListRow(
              title: goal.title,
              subtitle:
                  'Due ${DateFormat('MMM d').format(goal.targetDate!)} · ${goal.status.name}',
              dense: true,
              leading: Icon(
                goal.status == GoalStatus.achieved
                    ? Icons.check_circle_outline
                    : Icons.flag_outlined,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneySummary extends StatelessWidget {
  const _MoneySummary({required this.all});

  final List<MoneyTransaction> all;

  @override
  Widget build(BuildContext context) {
    // Per-currency in/out — amounts in different currencies are never summed.
    final Map<String, double> income = <String, double>{};
    final Map<String, double> expense = <String, double>{};
    for (final MoneyTransaction transaction in all) {
      final String currency = transaction.amount.currency;
      final double amount = transaction.amount.amount;
      switch (transaction.kind) {
        case TransactionKind.income:
          income.update(
            currency,
            (double total) => total + amount,
            ifAbsent: () => amount,
          );
        case TransactionKind.expense:
          expense.update(
            currency,
            (double total) => total + amount,
            ifAbsent: () => amount,
          );
        case TransactionKind.transfer:
          break;
      }
    }

    final List<String> currencies =
        <String>{...income.keys, ...expense.keys}.toList()..sort();
    if (currencies.isEmpty) {
      return const AppCard(
        child: Text('No transactions recorded this month.'),
      );
    }

    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        children: <Widget>[
          for (final String currency in currencies)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(currency, style: AppTypography.titleMedium),
                  ),
                  Text(
                    'In ${_format(currency, income[currency] ?? 0)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.semanticColors.income,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Text(
                    'Out ${_format(currency, expense[currency] ?? 0)}',
                    style: AppTypography.bodyMedium.copyWith(
                      color: context.semanticColors.expense,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _format(String currency, double amount) {
    return NumberFormat.simpleCurrency(name: currency).format(amount);
  }
}
