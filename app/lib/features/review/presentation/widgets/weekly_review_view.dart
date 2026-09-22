import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/review_entities.dart';
import '../providers/review_providers.dart';
import 'review_widgets.dart';

/// Design 20 "Weekly review": serif execution stats with a per-day focus
/// bar chart, the week's money, and reflection prompts.
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
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: <Widget>[
        ReviewNavHeader(
          eyebrow: 'Review',
          label: 'Your week',
          sub:
              '${DateFormat('MMMM d').format(_weekStart)} – ${DateFormat('d').format(weekEnd)}',
          onPrevious: () => setState(
            () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
          ),
          onNext: () => setState(
            () => _weekStart = _weekStart.add(const Duration(days: 7)),
          ),
        ),
        const SizedBox(height: 28),
        const LumaEyebrow('Execution'),
        const SizedBox(height: 14),
        _ExecutionSection(weekStart: _weekStart),
        const SizedBox(height: 28),
        const LumaEyebrow('Money this week'),
        const SizedBox(height: 4),
        _WeekMoney(weekStart: _weekStart),
        const SizedBox(height: 28),
        const LumaEyebrow('Reflection'),
        const SizedBox(height: 20),
        review.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the review.'),
          data: (WeeklyReview? existing) => ReviewStubForm(
            key: ValueKey<String>('weekly-review-$_weekStart-${existing?.id}'),
            fields: <ReviewFieldSpec>[
              ReviewFieldSpec(
                id: 'wentWell',
                label: 'What moved you forward?',
                hint: 'Wins worth repeating…',
                initialValue: existing?.wentWell,
              ),
              ReviewFieldSpec(
                id: 'wentPoorly',
                label: 'What wasted time?',
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
                label: 'What should change next week?',
                hint: 'The one thing that matters…',
                initialValue: existing?.nextWeekFocus,
              ),
            ],
            onSave: (Map<String, String?> values) => _save(existing, values),
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

/// Serif stat pair + per-day focus bars (design 20's execution block).
class _ExecutionSection extends ConsumerWidget {
  const _ExecutionSection({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime weekEndExclusive = weekStart.add(const Duration(days: 7));

    final List<Task> allTasks =
        ref.watch(reviewAllTasksProvider).value ?? <Task>[];
    final List<Task> scheduledThisWeek = allTasks.where((Task t) {
      final DateTime? d = t.scheduledDate;
      return d != null &&
          !d.isBefore(weekStart) &&
          d.isBefore(weekEndExclusive);
    }).toList(growable: false);
    final int completed = scheduledThisWeek
        .where((Task t) => t.status == TaskStatus.done)
        .length;

    final int focusMinutes = ref
            .watch(reviewFocusMinutesForRangeProvider((weekStart, 7)))
            .value ??
        0;

    final List<int> byDay = <int>[
      for (int i = 0; i < 7; i++)
        ref
                .watch(reviewFocusMinutesForRangeProvider(
                    (weekStart.add(Duration(days: i)), 1)))
                .value ??
            0,
    ];
    final int maxDay =
        byDay.fold(0, (int max, int v) => v > max ? v : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _BigStat(
                value: '$completed',
                label: 'tasks completed',
              ),
            ),
            Expanded(
              child: _BigStat(
                value:
                    '${focusMinutes ~/ 60}h ${(focusMinutes % 60).toString().padLeft(2, '0')}m',
                label: 'focused',
              ),
            ),
          ],
        ),
        if (maxDay > 0) ...<Widget>[
          const SizedBox(height: 20),
          SizedBox(
            height: 130,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                for (int i = 0; i < 7; i++) ...<Widget>[
                  if (i > 0) const Spacer(),
                  _DayBar(
                    minutes: byDay[i],
                    maxMinutes: maxDay,
                    label: 'MTWTFSS'[i],
                    weekend: i >= 5,
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value, style: lumaSerif(size: 40, height: 1)),
        const SizedBox(height: 4),
        Text(label, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
      ],
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.minutes,
    required this.maxMinutes,
    required this.label,
    required this.weekend,
  });

  final int minutes;
  final int maxMinutes;
  final String label;
  final bool weekend;

  @override
  Widget build(BuildContext context) {
    final double height =
        maxMinutes == 0 ? 0 : 96 * minutes / maxMinutes;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: <Widget>[
        Container(
          width: 26,
          height: height < 4 && minutes > 0 ? 4 : height,
          decoration: BoxDecoration(
            color: weekend ? const Color(0xFFB9C4DB) : LumaColors.accent,
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: lumaSans(size: 11, color: LumaColors.ink3)),
      ],
    );
  }
}

/// Hairline money rows (in/out per currency).
class _WeekMoney extends ConsumerWidget {
  const _WeekMoney({required this.weekStart});

  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    if (incomeByCurrency.isEmpty && expenseByCurrency.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Text('No transactions this week.',
            style: lumaSans(size: 13, color: LumaColors.ink3)),
      );
    }

    return Column(
      children: <Widget>[
        for (final MapEntry<String, double> entry
            in expenseByCurrency.entries)
          _MoneyLine(
            label: 'Spent (${entry.key})',
            value: _fmt(entry.value, entry.key),
          ),
        for (final MapEntry<String, double> entry
            in incomeByCurrency.entries)
          _MoneyLine(
            label: 'Income (${entry.key})',
            value: _fmt(entry.value, entry.key),
            valueColor: LumaColors.positive,
          ),
      ],
    );
  }

  static String _fmt(double amount, String currency) {
    return NumberFormat.simpleCurrency(name: currency, decimalDigits: 0)
        .format(amount);
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    required this.label,
    required this.value,
    this.valueColor = LumaColors.ink,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      child: Row(
        children: <Widget>[
          Text(label, style: lumaSans(size: 14, color: LumaColors.ink3)),
          const Spacer(),
          Text(value,
              style: lumaSans(
                  size: 14, weight: FontWeight.w500, color: valueColor)),
        ],
      ),
    );
  }
}
