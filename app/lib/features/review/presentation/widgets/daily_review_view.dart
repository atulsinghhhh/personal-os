import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/review_entities.dart';
import '../providers/review_providers.dart';
import 'review_widgets.dart';

/// Design 19 "Daily review": the day in serif numbers, a feeling chip row,
/// and reflection prompts in the design's serif voice.
class DailyReviewView extends ConsumerStatefulWidget {
  const DailyReviewView({super.key});

  @override
  ConsumerState<DailyReviewView> createState() => _DailyReviewViewState();
}

class _DailyReviewViewState extends ConsumerState<DailyReviewView> {
  DateTime _date = reviewUtcDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DailyReview?> review =
        ref.watch(dailyReviewForDateProvider(_date));
    final DateTime now = DateTime.now();
    final bool evening = now.hour >= 17;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: <Widget>[
        ReviewNavHeader(
          eyebrow:
              '${evening ? 'Evening' : 'Daily'} review · ${DateFormat('HH:mm').format(now)}',
          label: DateFormat('EEEE').format(_date),
          sub: DateFormat('MMMM d, y').format(_date),
          onPrevious: () => setState(
            () => _date = _date.subtract(const Duration(days: 1)),
          ),
          onNext: () =>
              setState(() => _date = _date.add(const Duration(days: 1))),
        ),
        const SizedBox(height: 28),
        _DayNumbers(date: _date),
        const SizedBox(height: 28),
        review.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the review.'),
          data: (DailyReview? existing) => _DailyReviewForm(
            key: ValueKey<String>('daily-review-$_date-${existing?.id}'),
            date: _date,
            existing: existing,
          ),
        ),
      ],
    );
  }
}

/// The day in numbers: a 2-column serif stat grid between hairlines.
class _DayNumbers extends ConsumerWidget {
  const _DayNumbers({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Task> tasks =
        ref.watch(reviewTasksForDateProvider(date)).value ?? const <Task>[];
    final int minutes = ref.watch(reviewFocusMinutesProvider(date)).value ?? 0;
    final List<MoneyTransaction> transactions =
        ref.watch(reviewTransactionsForDateProvider(date)).value ??
            const <MoneyTransaction>[];

    final int done =
        tasks.where((Task task) => task.status == TaskStatus.done).length;

    final List<MoneyTransaction> expenses = transactions
        .where((MoneyTransaction t) => t.kind == TransactionKind.expense)
        .toList(growable: false);
    String spent = '—';
    if (expenses.isNotEmpty) {
      final String currency = expenses.first.amount.currency;
      final double total = expenses
          .where((MoneyTransaction t) => t.amount.currency == currency)
          .fold(0, (double sum, MoneyTransaction t) => sum + t.amount.amount);
      spent = NumberFormat.simpleCurrency(name: currency, decimalDigits: 0)
          .format(total);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: LumaColors.hairline),
          bottom: BorderSide(color: LumaColors.hairline),
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                  child:
                      _Stat(value: '$done', label: 'tasks completed')),
              Expanded(
                child: _Stat(
                  value:
                      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m',
                  label: 'focused',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _Stat(
                  value: spent,
                  label: expenses.isEmpty
                      ? 'spent'
                      : 'spent · ${expenses.length} transaction${expenses.length == 1 ? '' : 's'}',
                ),
              ),
              Expanded(
                child: _Stat(
                  value: '${tasks.length - done}',
                  label: 'tasks left',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(value, style: lumaSerif(size: 30)),
        Text(label, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
      ],
    );
  }
}

class _DailyReviewForm extends ConsumerStatefulWidget {
  const _DailyReviewForm({
    super.key,
    required this.date,
    required this.existing,
  });

  final DateTime date;
  final DailyReview? existing;

  @override
  ConsumerState<_DailyReviewForm> createState() => _DailyReviewFormState();
}

class _DailyReviewFormState extends ConsumerState<_DailyReviewForm> {
  late int? _energy = widget.existing?.energy;
  late int? _focus = widget.existing?.focus;
  late int? _mood = widget.existing?.mood;
  late final TextEditingController _accomplished =
      TextEditingController(text: widget.existing?.accomplished ?? '');
  late final TextEditingController _blockedBy =
      TextEditingController(text: widget.existing?.blockedBy ?? '');
  late final TextEditingController _changeTomorrow =
      TextEditingController(text: widget.existing?.changeTomorrow ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _accomplished.dispose();
    _blockedBy.dispose();
    _changeTomorrow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        RatingSelector(
          label: 'How did today feel?',
          value: _mood,
          onChanged: (int value) => setState(() => _mood = value),
        ),
        const SizedBox(height: 24),
        RatingSelector(
          label: 'Energy',
          value: _energy,
          onChanged: (int value) => setState(() => _energy = value),
        ),
        const SizedBox(height: 24),
        RatingSelector(
          label: 'Focus',
          value: _focus,
          onChanged: (int value) => setState(() => _focus = value),
        ),
        const SizedBox(height: 28),
        ReviewPromptField(
          label: 'What went well?',
          controller: _accomplished,
        ),
        const SizedBox(height: 24),
        ReviewPromptField(
          label: 'What didn’t?',
          controller: _blockedBy,
        ),
        const SizedBox(height: 24),
        ReviewPromptField(
          label: 'Tomorrow',
          hint: 'One concrete adjustment…',
          controller: _changeTomorrow,
        ),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _saving ? null : _save,
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              color: LumaColors.ink,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              _saving ? 'Saving…' : 'Complete review',
              style: lumaSans(
                  size: 16,
                  weight: FontWeight.w600,
                  color: LumaColors.surface),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    setState(() => _saving = true);
    final DateTime now = DateTime.now().toUtc();
    final DailyReview? existing = widget.existing;
    final String accomplished = _accomplished.text.trim();
    final String blockedBy = _blockedBy.text.trim();
    final String changeTomorrow = _changeTomorrow.text.trim();
    await ref.read(dailyReviewRepositoryProvider).upsert(
          DailyReview(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            date: widget.date,
            energy: _energy,
            focus: _focus,
            mood: _mood,
            accomplished: accomplished.isEmpty ? null : accomplished,
            blockedBy: blockedBy.isEmpty ? null : blockedBy,
            changeTomorrow: changeTomorrow.isEmpty ? null : changeTomorrow,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review saved.')),
      );
    }
  }
}
