import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../domain/entities/plan_entities.dart';
import '../providers/plan_providers.dart';
import 'planner_widgets.dart';

/// Year view: a theme, the year's goals grouped by target month, and a
/// count of goals already achieved.
class YearPlannerView extends ConsumerStatefulWidget {
  const YearPlannerView({super.key});

  @override
  ConsumerState<YearPlannerView> createState() => _YearPlannerViewState();
}

class _YearPlannerViewState extends ConsumerState<YearPlannerView> {
  int _year = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<YearlyPlan?> plan =
        ref.watch(yearlyPlanForYearProvider(_year));
    final AsyncValue<List<Goal>> goals = ref.watch(allGoalsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        PlannerNavHeader(
          label: '$_year',
          onPrevious: () => setState(() => _year -= 1),
          onNext: () => setState(() => _year += 1),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('THEME', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        plan.when(
          loading: () => const LoadingShimmer(height: 120),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the year plan.'),
          data: (YearlyPlan? existing) => PlanTextFieldCard(
            key: ValueKey<String>('year-$_year-${existing?.id}'),
            label: 'Theme for the year',
            hint: 'e.g. The year of depth',
            initialValue: existing?.theme,
            onSave: (String value) => _saveTheme(existing, value),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        goals.when(
          loading: () => const LoadingShimmer(height: 200),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load goals.'),
          data: (List<Goal> all) => _YearGoals(all: all, year: _year),
        ),
      ],
    );
  }

  Future<void> _saveTheme(YearlyPlan? existing, String value) async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final DateTime now = DateTime.now().toUtc();
    await ref.read(yearlyPlanRepositoryProvider).upsert(
          YearlyPlan(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            year: _year,
            theme: value.isEmpty ? null : value,
            visionIds: existing?.visionIds ?? const <String>[],
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }
}

class _YearGoals extends StatelessWidget {
  const _YearGoals({required this.all, required this.year});

  final List<Goal> all;
  final int year;

  @override
  Widget build(BuildContext context) {
    final List<Goal> inYear = <Goal>[
      for (final Goal goal in all)
        if (goal.targetDate != null && goal.targetDate!.year == year) goal,
    ];
    final int achieved = inYear
        .where((Goal goal) => goal.status == GoalStatus.achieved)
        .length;

    final Map<int, List<Goal>> byMonth = <int, List<Goal>>{};
    for (final Goal goal in inYear) {
      byMonth.putIfAbsent(goal.targetDate!.month, () => <Goal>[]).add(goal);
    }
    final List<int> months = byMonth.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'GOALS ACHIEVED',
                style: AppTypography.labelSmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$achieved of ${inYear.length}',
                style: AppTypography.currencyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('GOALS BY MONTH', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        if (inYear.isEmpty)
          AppCard(child: Text('No goals with a target date in $year.'))
        else
          for (final int month in months) ...<Widget>[
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpacing.sm,
                bottom: AppSpacing.xs,
              ),
              child: Text(
                DateFormat('MMMM').format(DateTime.utc(year, month)),
                style: AppTypography.labelLarge.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            AppCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: <Widget>[
                  for (final Goal goal in byMonth[month]!)
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
            ),
          ],
      ],
    );
  }
}
