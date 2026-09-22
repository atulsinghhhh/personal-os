import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
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
