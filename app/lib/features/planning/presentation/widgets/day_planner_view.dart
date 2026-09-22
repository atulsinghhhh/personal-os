import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../calendar/domain/entities/calendar_entities.dart';
import '../../../future/presentation/widgets/edit_sheets.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/plan_entities.dart';
import '../providers/plan_providers.dart';
import 'planner_widgets.dart';

/// One day at a time: intention, scheduled tasks, time blocks, and an
/// overload warning when more work is planned than time remains.
class DayPlannerView extends ConsumerStatefulWidget {
  const DayPlannerView({super.key});

  @override
  ConsumerState<DayPlannerView> createState() => _DayPlannerViewState();
}

class _DayPlannerViewState extends ConsumerState<DayPlannerView> {
  DateTime _date = utcDate(DateTime.now());

  bool get _isToday => _date == utcDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DailyPlan?> plan =
        ref.watch(dailyPlanForDateProvider(_date));
    final AsyncValue<List<Task>> tasks = ref.watch(tasksForDateProvider(_date));
    final AsyncValue<List<TimeBlock>> blocks =
        ref.watch(timeBlocksForDateProvider(_date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.huge,
      ),
      children: <Widget>[
        PlannerNavHeader(
          label: DateFormat('EEE, MMM d yyyy').format(_date),
          onPrevious: () => setState(
            () => _date = _date.subtract(const Duration(days: 1)),
          ),
          onNext: () =>
              setState(() => _date = _date.add(const Duration(days: 1))),
        ),
        const SizedBox(height: AppSpacing.md),
        _OverloadWarning(tasks: tasks, isToday: _isToday),
        Text('INTENTION', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        plan.when(
          loading: () => const LoadingShimmer(height: 120),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load the day plan.'),
          data: (DailyPlan? existing) => PlanTextFieldCard(
            key: ValueKey<String>('intention-$_date-${existing?.id}'),
            label: 'Intention for the day',
            hint: 'What would make today a win?',
            initialValue: existing?.intention,
            onSave: (String value) => _saveIntention(existing, value),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('TASKS', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        tasks.when(
          loading: () => const LoadingShimmer(height: 160),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load tasks.'),
          data: (List<Task> all) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (all.isEmpty)
                const AppCard(
                  child: Text('Nothing scheduled for this day yet.'),
                )
              else
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    children: <Widget>[
                      for (final Task task in all) TaskCheckRow(task: task),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Add task',
                  icon: Icons.add,
                  variant: AppButtonVariant.text,
                  onPressed: () {
                    if (_isToday) {
                      // The shared sheet only supports "schedule for today".
                      showTaskSheet(context, ref, scheduleToday: true);
                    } else {
                      _showTaskForDateSheet();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('TIME BLOCKS', style: plannerSectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        blocks.when(
          loading: () => const LoadingShimmer(height: 100),
          error: (Object error, _) =>
              const ErrorStateView(message: 'Could not load time blocks.'),
          data: (List<TimeBlock> all) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (all.isEmpty)
                const AppCard(child: Text('No time blocks for this day.'))
              else
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Column(
                    children: <Widget>[
                      for (final TimeBlock block in all)
                        _TimeBlockRow(
                          block: block,
                          tasks: tasks.value ?? const <Task>[],
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: AppButton(
                  label: 'Add time block',
                  icon: Icons.add,
                  variant: AppButtonVariant.text,
                  onPressed: () =>
                      _showTimeBlockSheet(tasks.value ?? const <Task>[]),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveIntention(DailyPlan? existing, String value) async {
    final String? userId =
        ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;
    final DateTime now = DateTime.now().toUtc();
    await ref.read(dailyPlanRepositoryProvider).upsert(
          DailyPlan(
            id: existing?.id ?? const Uuid().v4(),
            userId: existing?.userId ?? userId,
            date: _date,
            intention: value.isEmpty ? null : value,
            taskIds: existing?.taskIds ?? const <String>[],
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
  }

  /// Inline task creation for non-today dates — the shared task sheet only
  /// knows how to schedule for today.
  Future<void> _showTaskForDateSheet() {
    final TextEditingController title = TextEditingController();
    final DateTime date = _date;
    return showAppBottomSheet<void>(
      context: context,
      title: 'New task · ${DateFormat('MMM d').format(date)}',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            AppTextField(
              controller: title,
              hint: 'What needs doing?',
              autofocus: true,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: () async {
                final String value = title.text.trim();
                final String? userId =
                    ref.read(supabaseClientProvider).auth.currentUser?.id;
                if (value.isEmpty || userId == null) return;
                final DateTime now = DateTime.now().toUtc();
                await ref.read(taskRepositoryProvider).create(
                      Task(
                        id: const Uuid().v4(),
                        userId: userId,
                        title: value,
                        status: TaskStatus.todo,
                        priority: 0,
                        scheduledDate: date,
                        actualMinutes: 0,
                        sortOrder: 0,
                        createdAt: now,
                        updatedAt: now,
                      ),
                    );
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTimeBlockSheet(List<Task> dayTasks) {
    final DateTime date = _date;
    String? taskId;
    TimeOfDay? start;
    TimeOfDay? end;
    return showAppBottomSheet<void>(
      context: context,
      title: 'New time block',
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DropdownButtonFormField<String?>(
                  initialValue: taskId,
                  decoration:
                      const InputDecoration(hintText: 'Linked task'),
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      child: Text('No linked task'),
                    ),
                    for (final Task task in dayTasks)
                      DropdownMenuItem<String?>(
                        value: task.id,
                        child: Text(
                          task.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (String? value) =>
                      setSheetState(() => taskId = value),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _TimeField(
                        label: 'Start',
                        value: start,
                        onChanged: (TimeOfDay value) =>
                            setSheetState(() => start = value),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: _TimeField(
                        label: 'End',
                        value: end,
                        onChanged: (TimeOfDay value) =>
                            setSheetState(() => end = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Save',
                  expand: true,
                  onPressed: () async {
                    final TimeOfDay? startTime = start;
                    final TimeOfDay? endTime = end;
                    final String? userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
                    if (startTime == null ||
                        endTime == null ||
                        userId == null) {
                      return;
                    }
                    final DateTime now = DateTime.now().toUtc();
                    await ref.read(timeBlockRepositoryProvider).create(
                          TimeBlock(
                            id: const Uuid().v4(),
                            userId: userId,
                            taskId: taskId,
                            date: date,
                            startAt: DateTime.utc(
                              date.year,
                              date.month,
                              date.day,
                              startTime.hour,
                              startTime.minute,
                            ),
                            endAt: DateTime.utc(
                              date.year,
                              date.month,
                              date.day,
                              endTime.hour,
                              endTime.minute,
                            ),
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: value ?? TimeOfDay.now(),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(value == null ? '--:--' : value!.format(context)),
                Icon(
                  Icons.schedule_outlined,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeBlockRow extends ConsumerWidget {
  const _TimeBlockRow({required this.block, required this.tasks});

  final TimeBlock block;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title = 'Time block';
    for (final Task task in tasks) {
      if (task.id == block.taskId) {
        title = task.title;
        break;
      }
    }
    final String range = (block.startAt == null || block.endAt == null)
        ? 'No time set'
        : '${_fmtTime(block.startAt!)} – ${_fmtTime(block.endAt!)}';

    return ListTile(
      dense: true,
      leading: const Icon(Icons.timelapse_outlined, size: 20),
      title: Text(title, style: AppTypography.bodyLarge),
      subtitle: Text(
        range,
        style: AppTypography.bodyMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline, size: 20),
        tooltip: 'Delete time block',
        onPressed: () =>
            ref.read(timeBlockRepositoryProvider).delete(block.id),
      ),
    );
  }

  static String _fmtTime(DateTime time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

/// Compares planned (estimates of incomplete tasks) against available time:
/// the gap until 22:00 for today, or an 8h default for other days. Warns
/// only — never modifies the plan.
class _OverloadWarning extends StatelessWidget {
  const _OverloadWarning({required this.tasks, required this.isToday});

  final AsyncValue<List<Task>> tasks;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final List<Task>? all = tasks.value;
    if (all == null) return const SizedBox.shrink();

    int planned = 0;
    for (final Task task in all) {
      if (task.status == TaskStatus.done ||
          task.status == TaskStatus.cancelled) {
        continue;
      }
      planned += task.estimateMinutes ?? 0;
    }

    int available = 8 * 60;
    if (isToday) {
      final DateTime now = DateTime.now();
      final DateTime dayEnd =
          DateTime(now.year, now.month, now.day, 22);
      available = dayEnd.isAfter(now) ? dayEnd.difference(now).inMinutes : 0;
    }

    if (planned <= available) return const SizedBox.shrink();

    final Color warning = context.semanticColors.warning;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: AppCard(
        color: warning.withValues(alpha: 0.12),
        child: Row(
          children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: warning),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'You have ${formatMinutes(planned - available)} more work '
                'planned than available.',
                style: AppTypography.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
