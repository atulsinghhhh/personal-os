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
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/plan_entities.dart';
import '../providers/plan_providers.dart';
import 'planner_widgets.dart';

/// The week at a glance: outcomes/reflection, scheduled tasks grouped by
/// day, and last week's unfinished tasks offered as carry-overs.
class WeekPlannerView extends ConsumerStatefulWidget {
  const WeekPlannerView({super.key});

  @override
  ConsumerState<WeekPlannerView> createState() => _WeekPlannerViewState();
}

class _WeekPlannerViewState extends ConsumerState<WeekPlannerView> {
  DateTime _weekStart = mondayOf(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final AsyncValue<WeeklyPlan?> plan =
        ref.watch(weeklyPlanForWeekProvider(_weekStart));
    final AsyncValue<List<Task>> tasks = ref.watch(allTasksProvider);
    final DateTime weekEnd = _weekStart.add(const Duration(days: 6));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        PlannerNavHeader(
          label: 'This week',
          sub:
              '${DateFormat('MMMM d').format(_weekStart)} – ${DateFormat('d').format(weekEnd)} · Week ${_weekNumber(_weekStart)}',
          onPrevious: () => setState(
            () => _weekStart = _weekStart.subtract(const Duration(days: 7)),
          ),
          onNext: () => setState(
            () => _weekStart = _weekStart.add(const Duration(days: 7)),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('WEEKLY PLAN', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        plan.when(
          loading: () => const LoadingShimmer(height: 200),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the week plan.'),
          data: (WeeklyPlan? existing) => _WeeklyPlanCard(
            key: ValueKey<String>('week-$_weekStart-${existing?.id}'),
            weekStart: _weekStart,
            existing: existing,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('CARRY OVER', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        tasks.when(
          loading: () => const LoadingShimmer(height: 80),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load tasks.'),
          data: (List<Task> all) =>
              _CarryOverList(all: all, weekStart: _weekStart),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('THIS WEEK', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        tasks.when(
          loading: () => const LoadingShimmer(height: 160),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load tasks.'),
          data: (List<Task> all) =>
              _WeekTaskList(all: all, weekStart: _weekStart),
        ),
      ],
    );
  }
}

class _WeeklyPlanCard extends ConsumerStatefulWidget {
  const _WeeklyPlanCard({
    super.key,
    required this.weekStart,
    required this.existing,
  });

  final DateTime weekStart;
  final WeeklyPlan? existing;

  @override
  ConsumerState<_WeeklyPlanCard> createState() => _WeeklyPlanCardState();
}

class _WeeklyPlanCardState extends ConsumerState<_WeeklyPlanCard> {
  late final TextEditingController _outcomes =
      TextEditingController(text: widget.existing?.outcomes ?? '');
  late final TextEditingController _reflection =
      TextEditingController(text: widget.existing?.reflection ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _outcomes.dispose();
    _reflection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _PromptField(
          label: 'Outcomes',
          hint: '“What must be true by Sunday?”',
          controller: _outcomes,
        ),
        const SizedBox(height: AppSpacing.xl),
        _PromptField(
          label: 'Reflection',
          hint: '“Notes as the week unfolds…”',
          controller: _reflection,
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: LumaTextButton(
            label: _saving ? 'Saving…' : 'Save',
            height: 36,
            fontSize: 14,
            color: LumaColors.accent,
            onTap: _saving ? null : _save,
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
    final WeeklyPlan? existing = widget.existing;
    final String outcomes = _outcomes.text.trim();
    final String reflection = _reflection.text.trim();
    await ref.read(weeklyPlanRepositoryProvider).upsert(
          WeeklyPlan(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            weekStart: widget.weekStart,
            focusGoalIds: existing?.focusGoalIds ?? const <String>[],
            outcomes: outcomes.isEmpty ? null : outcomes,
            reflection: reflection.isEmpty ? null : reflection,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
    if (mounted) setState(() => _saving = false);
  }
}

class _WeekTaskList extends StatelessWidget {
  const _WeekTaskList({required this.all, required this.weekStart});

  final List<Task> all;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final DateTime weekEnd = weekStart.add(const Duration(days: 7));
    final Map<DateTime, List<Task>> byDay = <DateTime, List<Task>>{};
    for (final Task task in all) {
      final DateTime? scheduled = task.scheduledDate;
      if (scheduled == null) continue;
      final DateTime day = utcDate(scheduled);
      if (day.isBefore(weekStart) || !day.isBefore(weekEnd)) continue;
      byDay.putIfAbsent(day, () => <Task>[]).add(task);
    }

    if (byDay.isEmpty) {
      return const AppCard(
        child: Text('Nothing scheduled this week yet.'),
      );
    }

    final List<DateTime> days = byDay.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final DateTime day in days) ...<Widget>[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.xs,
            ),
            child: Text(
              DateFormat('EEEE · MMM d').format(day),
              style: AppTypography.labelLarge.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Column(
              children: <Widget>[
                for (final Task task in byDay[day]!) TaskCheckRow(task: task),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Unfinished tasks scheduled in the previous week, each with a one-tap
/// reschedule onto this week's Monday.
class _CarryOverList extends ConsumerWidget {
  const _CarryOverList({required this.all, required this.weekStart});

  final List<Task> all;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime previousStart =
        weekStart.subtract(const Duration(days: 7));
    final List<Task> carryOver = <Task>[
      for (final Task task in all)
        if (task.status != TaskStatus.done &&
            task.status != TaskStatus.cancelled &&
            task.scheduledDate != null &&
            !utcDate(task.scheduledDate!).isBefore(previousStart) &&
            utcDate(task.scheduledDate!).isBefore(weekStart))
          task,
    ];

    if (carryOver.isEmpty) {
      return Text('Nothing unfinished from last week.',
          style: lumaSans(size: 13, color: LumaColors.ink3));
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < carryOver.length; i++)
          Container(
            constraints: const BoxConstraints(minHeight: 52),
            decoration: BoxDecoration(
              border: i > 0
                  ? const Border(
                      top: BorderSide(color: LumaColors.hairline))
                  : null,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(carryOver[i].title,
                          style:
                              lumaSans(size: 15, weight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text(
                        'Was ${DateFormat('EEE, MMM d').format(utcDate(carryOver[i].scheduledDate!))}',
                        style:
                            lumaSans(size: 12.5, color: LumaColors.ink3),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ref.read(taskRepositoryProvider).update(
                          carryOver[i].copyWith(
                            scheduledDate: weekStart,
                            updatedAt: DateTime.now().toUtc(),
                          ),
                        );
                  },
                  child: SizedBox(
                    height: 44,
                    child: Center(
                      child: Text('Move here',
                          style: lumaSans(
                              size: 13,
                              weight: FontWeight.w500,
                              color: LumaColors.accent)),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bold label over an underlined serif field — the design's prompt voice.
class _PromptField extends StatelessWidget {
  const _PromptField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  final String label;
  final String hint;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: lumaSans(size: 14, weight: FontWeight.w600)),
        const SizedBox(height: 10),
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: LumaColors.hairline)),
          ),
          padding: const EdgeInsets.only(bottom: 8),
          child: TextField(
            controller: controller,
            maxLines: 3,
            minLines: 1,
            style: lumaSerif(size: 21, height: 1.4),
            cursorColor: LumaColors.ink,
            decoration: InputDecoration(
              isCollapsed: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              hintText: hint,
              hintStyle:
                  lumaSerif(size: 21, height: 1.4, color: LumaColors.ink3),
            ),
          ),
        ),
      ],
    );
  }
}

/// ISO-8601 week number for the week containing [date].
int _weekNumber(DateTime date) {
  final DateTime thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 7 : date.weekday)));
  final DateTime firstDay = DateTime(thursday.year, 1, 1);
  return ((thursday.difference(firstDay).inDays) ~/ 7) + 1;
}
