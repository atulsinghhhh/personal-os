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
