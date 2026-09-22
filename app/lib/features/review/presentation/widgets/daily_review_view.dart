import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../money/transactions/domain/entities/transaction_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/review_entities.dart';
import '../providers/review_providers.dart';
import 'review_widgets.dart';

/// The full daily review: that day's numbers for context, 1–5 ratings for
/// energy/focus/mood, and three reflection prompts.
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        ReviewNavHeader(
          label: DateFormat('EEE, MMM d yyyy').format(_date),
          onPrevious: () => setState(
            () => _date = _date.subtract(const Duration(days: 1)),
          ),
          onNext: () =>
              setState(() => _date = _date.add(const Duration(days: 1))),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('THE DAY IN NUMBERS', style: reviewSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        _DayContextCard(date: _date),
        const SizedBox(height: AppSpacing.xl),
        Text('REVIEW', style: reviewSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        review.when(
          loading: () => const LoadingShimmer(height: 320),
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

class _DayContextCard extends ConsumerWidget {
  const _DayContextCard({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasks =
        ref.watch(reviewTasksForDateProvider(date));
    final AsyncValue<int> focusMinutes =
        ref.watch(reviewFocusMinutesProvider(date));
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(reviewTransactionsForDateProvider(date));

    if (tasks.isLoading || focusMinutes.isLoading || transactions.isLoading) {
      return const LoadingShimmer(height: 100);
    }
    if (tasks.hasError || focusMinutes.hasError || transactions.hasError) {
      return const ErrorStateView(
        message: "Could not load the day's numbers.",
      );
    }

    final List<Task> allTasks = tasks.value ?? const <Task>[];
    final int done = allTasks
        .where((Task task) => task.status == TaskStatus.done)
        .length;
    final int minutes = focusMinutes.value ?? 0;

    final Map<String, double> moneyIn = <String, double>{};
    final Map<String, double> moneyOut = <String, double>{};
    for (final MoneyTransaction transaction
        in transactions.value ?? const <MoneyTransaction>[]) {
      final String currency = transaction.amount.currency;
      final double amount = transaction.amount.amount;
      switch (transaction.kind) {
        case TransactionKind.income:
          moneyIn.update(
            currency,
            (double total) => total + amount,
            ifAbsent: () => amount,
          );
        case TransactionKind.expense:
          moneyOut.update(
            currency,
            (double total) => total + amount,
            ifAbsent: () => amount,
          );
        case TransactionKind.transfer:
          break;
      }
    }
    final List<String> currencies =
        <String>{...moneyIn.keys, ...moneyOut.keys}.toList()..sort();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: _ContextStat(
                  label: 'Tasks done',
                  value: '$done / ${allTasks.length}',
                ),
              ),
              Expanded(
                child: _ContextStat(
                  label: 'Focus',
                  value:
                      '${minutes ~/ 60}h ${(minutes % 60).toString().padLeft(2, '0')}m',
                ),
              ),
            ],
          ),
          if (currencies.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            // Per-currency in/out — never summed across currencies.
            for (final String currency in currencies)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        currency,
                        style: AppTypography.labelLarge,
                      ),
                    ),
                    Text(
                      'In ${_format(currency, moneyIn[currency] ?? 0)}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.semanticColors.income,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Text(
                      'Out ${_format(currency, moneyOut[currency] ?? 0)}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: context.semanticColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _format(String currency, double amount) {
    return NumberFormat.simpleCurrency(name: currency).format(amount);
  }
}

class _ContextStat extends StatelessWidget {
  const _ContextStat({required this.label, required this.value});

  final String label;
  final String value;

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
        Text(value, style: AppTypography.currencyMedium),
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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          RatingSelector(
            label: 'Energy',
            value: _energy,
            onChanged: (int value) => setState(() => _energy = value),
          ),
          RatingSelector(
            label: 'Focus',
            value: _focus,
            onChanged: (int value) => setState(() => _focus = value),
          ),
          RatingSelector(
            label: 'Mood',
            value: _mood,
            onChanged: (int value) => setState(() => _mood = value),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'What did you accomplish?',
            hint: 'Wins, shipped work, progress…',
            controller: _accomplished,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'What blocked you?',
            hint: 'Friction, interruptions, blockers…',
            controller: _blockedBy,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'What should change tomorrow?',
            hint: 'One concrete adjustment…',
            controller: _changeTomorrow,
            maxLines: 3,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Save review',
            expand: true,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
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
