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

/// Weekly review stub (Phase 1): six free-text prompts persisted per
/// Monday-normalized week.
class WeeklyReviewView extends ConsumerStatefulWidget {
  const WeeklyReviewView({super.key});

  @override
  ConsumerState<WeeklyReviewView> createState() => _WeeklyReviewViewState();
}

class _WeeklyReviewViewState extends ConsumerState<WeeklyReviewView> {
  DateTime _weekStart = reviewMondayOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WeeklyReview?> review =
        ref.watch(weeklyReviewForWeekProvider(_weekStart));
    final DateTime weekEnd = _weekStart.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        ReviewNavHeader(
          label:
              '${DateFormat('MMM d').format(_weekStart)} – ${DateFormat('MMM d, yyyy').format(weekEnd)}',
          onPrevious: () => setState(
            () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
          ),
          onNext: () => setState(
            () => _weekStart = _weekStart.add(const Duration(days: 7)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('THE WEEK IN NUMBERS', style: reviewSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        _WeekContextCard(weekStart: _weekStart),
        const SizedBox(height: AppSpacing.xl),
        Text('WEEKLY REVIEW', style: reviewSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        review.when(
          loading: () => const LoadingShimmer(height: 320),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the review.'),
          data: (WeeklyReview? existing) => ReviewStubForm(
            key: ValueKey<String>('weekly-review-$_weekStart-${existing?.id}'),
            fields: <ReviewFieldSpec>[
              ReviewFieldSpec(
                id: 'wentWell',
                label: 'What went well?',
                hint: 'Wins worth repeating…',
                initialValue: existing?.wentWell,
              ),
              ReviewFieldSpec(
                id: 'wentPoorly',
                label: 'What went poorly?',
                hint: 'Where the week leaked…',
                initialValue: existing?.wentPoorly,
              ),
              ReviewFieldSpec(
                id: 'learned',
                label: 'What did you learn?',
                hint: 'Insights, surprises…',
                initialValue: existing?.learned,
              ),
              ReviewFieldSpec(
                id: 'stopDoing',
                label: 'What should you stop doing?',
                hint: 'Habits to drop…',
                initialValue: existing?.stopDoing,
              ),
              ReviewFieldSpec(
                id: 'continueDoing',
                label: 'What should you continue doing?',
                hint: 'Keep what works…',
                initialValue: existing?.continueDoing,
              ),
              ReviewFieldSpec(
                id: 'nextWeekFocus',
                label: 'Next week focus',
                hint: 'The one thing that matters…',
                initialValue: existing?.nextWeekFocus,
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
    WeeklyReview? existing,
    Map<String, String?> values,
  ) async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final DateTime now = DateTime.now().toUtc();
    await ref.read(weeklyReviewRepositoryProvider).upsert(
          WeeklyReview(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            weekStart: _weekStart,
            wentWell: values['wentWell'],
            wentPoorly: values['wentPoorly'],
            learned: values['learned'],
            stopDoing: values['stopDoing'],
            continueDoing: values['continueDoing'],
            nextWeekFocus: values['nextWeekFocus'],
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }
}

class _WeekContextCard extends ConsumerWidget {
  const _WeekContextCard({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime weekEndExclusive = weekStart.add(const Duration(days: 7));

    final List<Task> allTasks =
        ref.watch(reviewAllTasksProvider).value ?? <Task>[];
    final List<Task> scheduledThisWeek = allTasks.where((Task t) {
      final DateTime? d = t.scheduledDate;
      return d != null && !d.isBefore(weekStart) && d.isBefore(weekEndExclusive);
    }).toList(growable: false);
    final int completed = scheduledThisWeek
        .where((Task t) => t.status == TaskStatus.done)
        .length;

    final int focusMinutes = ref
            .watch(reviewFocusMinutesForRangeProvider((weekStart, 7)))
            .value ??
        0;

    final List<MoneyTransaction> transactions = ref
            .watch(reviewTransactionsForRangeProvider((weekStart, 7)))
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
          !g.updatedAt.isBefore(weekStart) &&
          g.updatedAt.isBefore(weekEndExclusive);
    }).length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StatLine(
            label: 'Tasks',
            value: '$completed / ${scheduledThisWeek.length} completed',
          ),
          _StatLine(
            label: 'Focus time',
            value:
                '${focusMinutes ~/ 60}h ${(focusMinutes % 60).toString().padLeft(2, '0')}m',
          ),
          for (final MapEntry<String, double> entry
              in incomeByCurrency.entries)
            _StatLine(
              label: 'Income (${entry.key})',
              value: _fmt(entry.value, entry.key),
            ),
          for (final MapEntry<String, double> entry
              in expenseByCurrency.entries)
            _StatLine(
              label: 'Expenses (${entry.key})',
              value: _fmt(entry.value, entry.key),
            ),
          if (achieved > 0)
            _StatLine(
              label: 'Goals marked achieved this week',
              value: '$achieved',
            ),
        ],
      ),
    );
  }

  static String _fmt(double amount, String currency) {
    return NumberFormat.simpleCurrency(name: currency).format(amount);
  }
}

class _StatLine extends StatelessWidget {
  const _StatLine({required this.label, required this.value});

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
