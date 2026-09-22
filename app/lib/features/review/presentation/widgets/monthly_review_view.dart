import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/review_entities.dart';
import '../providers/review_providers.dart';
import 'review_widgets.dart';

/// Monthly review stub (Phase 1): five free-text prompts persisted per
/// first-of-month.
class MonthlyReviewView extends ConsumerStatefulWidget {
  const MonthlyReviewView({super.key});

  @override
  ConsumerState<MonthlyReviewView> createState() =>
      _MonthlyReviewViewState();
}

class _MonthlyReviewViewState extends ConsumerState<MonthlyReviewView> {
  DateTime _month = DateTime.utc(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<MonthlyReview?> review =
        ref.watch(monthlyReviewForMonthProvider(_month));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        ReviewNavHeader(
          label: DateFormat('MMMM yyyy').format(_month),
          onPrevious: () => setState(
            () => _month = DateTime.utc(_month.year, _month.month - 1),
          ),
          onNext: () => setState(
            () => _month = DateTime.utc(_month.year, _month.month + 1),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('THE MONTH IN NUMBERS', style: reviewSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        _MonthContextCard(month: _month),
        const SizedBox(height: AppSpacing.xl),
        Text('MONTHLY REVIEW', style: reviewSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        review.when(
          loading: () => const LoadingShimmer(height: 320),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the review.'),
          data: (MonthlyReview? existing) => ReviewStubForm(
            key: ValueKey<String>('monthly-review-$_month-${existing?.id}'),
            fields: <ReviewFieldSpec>[
              ReviewFieldSpec(
                id: 'summary',
                label: 'Summary',
                hint: 'The month in a few lines…',
                initialValue: existing?.summary,
              ),
              ReviewFieldSpec(
                id: 'whatMattered',
                label: 'What mattered?',
                hint: 'The work and moments that counted…',
                initialValue: existing?.whatMattered,
              ),
              ReviewFieldSpec(
                id: 'whatWastedTime',
                label: 'What wasted time?',
                hint: 'Low-value drains…',
                initialValue: existing?.whatWastedTime,
              ),
              ReviewFieldSpec(
                id: 'whatWasWorthTheMoney',
                label: 'What was worth the money?',
                hint: 'Spending that paid off…',
                initialValue: existing?.whatWasWorthTheMoney,
              ),
              ReviewFieldSpec(
                id: 'changeNextMonth',
                label: 'What changes next month?',
                hint: 'One concrete adjustment…',
                initialValue: existing?.changeNextMonth,
              ),
            ],
            onSave: (Map<String, String?> values) =>
                _save(existing, values),
          ),
        ),
      ],
    );
  }

  Future<void> _save(
    MonthlyReview? existing,
    Map<String, String?> values,
  ) async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final DateTime now = DateTime.now().toUtc();
    await ref.read(monthlyReviewRepositoryProvider).upsert(
          MonthlyReview(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            month: _month,
            summary: values['summary'],
            whatMattered: values['whatMattered'],
            whatWastedTime: values['whatWastedTime'],
            whatWasWorthTheMoney: values['whatWasWorthTheMoney'],
            changeNextMonth: values['changeNextMonth'],
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }
}

class _MonthContextCard extends ConsumerWidget {
  const _MonthContextCard({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime monthEndExclusive =
        DateTime.utc(month.year, month.month + 1);
    final int daysInMonth = monthEndExclusive.difference(month).inDays;

    final List<Task> allTasks =
        ref.watch(reviewAllTasksProvider).value ?? <Task>[];
    final List<Task> scheduledThisMonth = allTasks.where((Task t) {
      final DateTime? d = t.scheduledDate;
      return d != null && !d.isBefore(month) && d.isBefore(monthEndExclusive);
    }).toList(growable: false);
    final int completed = scheduledThisMonth
        .where((Task t) => t.status == TaskStatus.done)
        .length;

    final int focusMinutes = ref
            .watch(reviewFocusMinutesForRangeProvider((month, daysInMonth)))
            .value ??
        0;

    final List<MoneyTransaction> transactions = ref
            .watch(
              reviewTransactionsForRangeProvider((month, daysInMonth)),
            )
            .value ??
        <MoneyTransaction>[];
    final Map<String, double> incomeByCurrency = <String, double>{};
    final Map<String, double> expenseByCurrency = <String, double>{};
    for (final MoneyTransaction t in transactions) {
      final Map<String, double> target = switch (t.kind) {
        TransactionKind.income => incomeByCurrency,
        TransactionKind.expense => expenseByCurrency,
        TransactionKind.transfer => <String, double>{},
      };
      target.update(
        t.amount.currency,
        (double v) => v + t.amount.amount,
        ifAbsent: () => t.amount.amount,
      );
    }

    final List<Goal> allGoals =
        ref.watch(reviewAllGoalsProvider).value ?? <Goal>[];
    final int achieved = allGoals.where((Goal g) {
      return g.status == GoalStatus.achieved &&
          !g.updatedAt.isBefore(month) &&
          g.updatedAt.isBefore(monthEndExclusive);
    }).length;

    final List<Project> allProjects =
        ref.watch(reviewAllProjectsProvider).value ?? <Project>[];
    final int projectsCompleted = allProjects.where((Project p) {
      return p.status == ProjectStatus.completed &&
          !p.updatedAt.isBefore(month) &&
          p.updatedAt.isBefore(monthEndExclusive);
    }).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MonthStatLine(
            label: 'Tasks',
            value: '$completed / ${scheduledThisMonth.length} completed',
          ),
          _MonthStatLine(
            label: 'Focus time',
            value:
                '${focusMinutes ~/ 60}h ${(focusMinutes % 60).toString().padLeft(2, '0')}m',
          ),
          for (final MapEntry<String, double> entry
              in incomeByCurrency.entries)
            _MonthStatLine(
              label: 'Income (${entry.key})',
              value: NumberFormat.simpleCurrency(name: entry.key)
                  .format(entry.value),
            ),
          for (final MapEntry<String, double> entry
              in expenseByCurrency.entries)
            _MonthStatLine(
              label: 'Expenses (${entry.key})',
              value: NumberFormat.simpleCurrency(name: entry.key)
                  .format(entry.value),
            ),
          if (achieved > 0)
            _MonthStatLine(
              label: 'Goals marked achieved this month',
              value: '$achieved',
            ),
          if (projectsCompleted > 0)
            _MonthStatLine(
              label: 'Projects marked completed this month',
              value: '$projectsCompleted',
            ),
        ],
      ),
    );
  }
}

class _MonthStatLine extends StatelessWidget {
  const _MonthStatLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(
            label,
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: AppTypography.labelLarge),
        ],
      ),
    );
  }
}
