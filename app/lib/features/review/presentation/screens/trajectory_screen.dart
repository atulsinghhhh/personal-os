import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../focus/domain/entities/focus_session.dart';
import '../../../future/domain/entities/future_entities.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../money/financial_goals/domain/entities/financial_goal.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';

/// Everything the trajectory view derives, computed in one pass from local
/// data. All numbers are plain arithmetic on recorded rows; each section's
/// caption states its inputs (product rule: always expose assumptions).
class TrajectoryData {
  const TrajectoryData({
    required this.lifeAreas,
    required this.goalsByArea,
    required this.focusMinutesByArea,
    required this.weekFocusMinutes,
    required this.monthExpensesByCurrency,
    required this.goalSpend,
    required this.financialGoals,
  });

  final List<LifeArea> lifeAreas;
  final Map<String, List<Goal>> goalsByArea;
  final Map<String, int> focusMinutesByArea;
  final int weekFocusMinutes;
  final Map<String, double> monthExpensesByCurrency;
  final Map<String, List<Money>> goalSpend; // goalId -> money invested
  final List<FinancialGoal> financialGoals;
}

final FutureProvider<TrajectoryData> trajectoryProvider =
    FutureProvider<TrajectoryData>((Ref ref) async {
  final List<LifeArea> areas =
      await ref.read(lifeAreaRepositoryProvider).watchAll().first;
  final List<Goal> goals =
      await ref.read(goalRepositoryProvider).watchAll().first;

  final Map<String, List<Goal>> goalsByArea = <String, List<Goal>>{};
  for (final Goal goal in goals) {
    if (goal.lifeAreaId == null) continue;
    goalsByArea.putIfAbsent(goal.lifeAreaId!, () => <Goal>[]).add(goal);
  }

  // Focus minutes last 7 days, attributed to life areas through each
  // area's goals (session -> task -> project -> goal -> area).
  final DateTime now = DateTime.now();
  final DateTime weekAgo =
      DateTime.utc(now.year, now.month, now.day - 7);
  final List<FocusSession> weekSessions = await ref
      .read(focusSessionRepositoryProvider)
      .watchForDateRange(weekAgo, DateTime.utc(now.year, now.month, now.day + 1))
      .first;
  final int weekFocusMinutes = weekSessions.fold<int>(
    0,
    (int total, FocusSession s) => total + (s.durationMinutes ?? 0),
  );

  final Map<String, int> focusByArea = <String, int>{};
  for (final MapEntry<String, List<Goal>> entry in goalsByArea.entries) {
    int minutes = 0;
    for (final Goal goal in entry.value) {
      minutes += await ref
          .read(focusSessionRepositoryProvider)
          .totalMinutesForGoal(goal.id);
    }
    if (minutes > 0) focusByArea[entry.key] = minutes;
  }

  // This month's expenses per currency.
  final DateTime monthStart = DateTime.utc(now.year, now.month);
  final List<MoneyTransaction> monthTxns = await ref
      .read(transactionRepositoryProvider)
      .watchForRange(monthStart, DateTime.utc(now.year, now.month + 1))
      .first;
  final Map<String, double> monthExpenses = <String, double>{};
  for (final MoneyTransaction t in monthTxns) {
    if (t.kind != TransactionKind.expense) continue;
    monthExpenses.update(
      t.amount.currency,
      (double v) => v + t.amount.amount,
      ifAbsent: () => t.amount.amount,
    );
  }

  // Money invested per goal (all time).
  final Map<String, List<Money>> goalSpend = <String, List<Money>>{};
  for (final Goal goal in goals) {
    final List<Money> spend = await ref
        .read(transactionRepositoryProvider)
        .totalSpentForGoal(goal.id);
    if (spend.isNotEmpty) goalSpend[goal.id] = spend;
  }

  final List<FinancialGoal> financialGoals =
      await ref.read(financialGoalRepositoryProvider).watchAll().first;

  return TrajectoryData(
    lifeAreas: areas,
    goalsByArea: goalsByArea,
    focusMinutesByArea: focusByArea,
    weekFocusMinutes: weekFocusMinutes,
    monthExpensesByCurrency: monthExpenses,
    goalSpend: goalSpend,
    financialGoals: financialGoals,
  );
});

class TrajectoryScreen extends ConsumerWidget {
  const TrajectoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TrajectoryData> data = ref.watch(trajectoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trajectory')),
      body: data.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: LoadingShimmer(height: 200),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not compute your trajectory.'),
        data: (TrajectoryData t) {
          if (t.lifeAreas.isEmpty) {
            return const EmptyStateView(
              message:
                  'Create life areas and goals to see your trajectory.',
              icon: Icons.insights_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Text('GOAL PROGRESS BY LIFE AREA', style: _label(context)),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: <Widget>[
                    for (final LifeArea area in t.lifeAreas)
                      _AreaProgressRow(
                        area: area,
                        goals: t.goalsByArea[area.id] ?? const <Goal>[],
                        focusMinutes: t.focusMinutesByArea[area.id] ?? 0,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bars: goals marked achieved ÷ all goals in the area. Time '
                'chips: all-time focus minutes on that area\'s goals.',
                style: _caption(context),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('LAST 7 DAYS', style: _label(context)),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${t.weekFocusMinutes ~/ 60}h '
                      '${(t.weekFocusMinutes % 60).toString().padLeft(2, '0')}m '
                      'of recorded focus time',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Sum of completed focus sessions in the last 7 days.',
                      style: _caption(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('THIS MONTH\'S SPENDING', style: _label(context)),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: t.monthExpensesByCurrency.isEmpty
                    ? const Text('No expenses recorded this month.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          for (final MapEntry<String, double> entry
                              in t.monthExpensesByCurrency.entries)
                            Text(
                              NumberFormat.simpleCurrency(name: entry.key)
                                  .format(entry.value),
                              style: AppTypography.currencyMedium,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('FINANCIAL GOAL PACING', style: _label(context)),
              const SizedBox(height: AppSpacing.sm),
              if (t.financialGoals.isEmpty)
                const AppCard(
                  child: Text('No financial goals with targets yet.'),
                )
              else
                for (final FinancialGoal goal in t.financialGoals)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _FinancialGoalPacing(goal: goal),
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

  static TextStyle _caption(BuildContext context) =>
      AppTypography.labelSmall.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      );
}

class _AreaProgressRow extends StatelessWidget {
  const _AreaProgressRow({
    required this.area,
    required this.goals,
    required this.focusMinutes,
  });

  final LifeArea area;
  final List<Goal> goals;
  final int focusMinutes;

  @override
  Widget build(BuildContext context) {
    final int achieved =
        goals.where((Goal g) => g.status == GoalStatus.achieved).length;
    final double fraction = goals.isEmpty ? 0 : achieved / goals.length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(area.name, style: AppTypography.titleMedium),
              ),
              Text(
                goals.isEmpty
                    ? 'no goals'
                    : '$achieved/${goals.length}'
                        '${focusMinutes > 0 ? ' · ${focusMinutes ~/ 60}h' : ''}',
                style: AppTypography.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(value: fraction),
        ],
      ),
    );
  }
}

class _FinancialGoalPacing extends StatelessWidget {
  const _FinancialGoalPacing({required this.goal});

  final FinancialGoal goal;

  @override
  Widget build(BuildContext context) {
    final Money? target = goal.targetAmount;
    final DateTime? deadline = goal.targetDate;

    String pacing;
    if (target == null) {
      pacing = 'No target amount set.';
    } else if (deadline == null) {
      pacing = 'Target ${NumberFormat.simpleCurrency(name: target.currency).format(target.amount)}, no deadline set.';
    } else {
      final DateTime now = DateTime.now();
      final int monthsRemaining =
          ((deadline.year - now.year) * 12 + deadline.month - now.month)
              .clamp(1, 1200);
      final double perMonth = target.amount / monthsRemaining;
      pacing =
          'Requires ~${NumberFormat.simpleCurrency(name: target.currency).format(perMonth)}'
          '/month until ${DateFormat.yMMM().format(deadline)}.';
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(goal.name, style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(pacing, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Projection: target ÷ months remaining, assuming equal monthly '
            'contributions from zero. Edit the goal to change the inputs.',
            style: AppTypography.labelSmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
