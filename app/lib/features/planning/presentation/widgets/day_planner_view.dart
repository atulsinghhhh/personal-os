import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/luma_text_field.dart';
import '../../../calendar/domain/entities/calendar_entities.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/plan_entities.dart';
import '../providers/plan_providers.dart';
import 'planner_widgets.dart';

/// Design 12 "Day planner": serif day header with a week strip, an hour grid
/// with positioned time blocks and a now line, unscheduled task chips, and
/// the day intention. Tapping a free slot creates a block there.
class DayPlannerView extends ConsumerStatefulWidget {
  const DayPlannerView({super.key});

  @override
  ConsumerState<DayPlannerView> createState() => _DayPlannerViewState();
}

class _DayPlannerViewState extends ConsumerState<DayPlannerView> {
  DateTime _date = utcDate(DateTime.now());

  static const int _firstHour = 7;
  static const int _lastHour = 21;
  static const double _hourHeight = 62;

  bool get _isToday => _date == utcDate(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final AsyncValue<DailyPlan?> plan =
        ref.watch(dailyPlanForDateProvider(_date));
    final List<Task> tasks =
        ref.watch(tasksForDateProvider(_date)).value ?? const <Task>[];
    final List<TimeBlock> blocks =
        ref.watch(timeBlocksForDateProvider(_date)).value ??
            const <TimeBlock>[];

    final int plannedMinutes = blocks.fold(0, (int sum, TimeBlock b) {
      if (b.startAt == null || b.endAt == null) return sum;
      return sum + b.endAt!.difference(b.startAt!).inMinutes;
    });

    final Set<String> blockedTaskIds = <String>{
      for (final TimeBlock b in blocks)
        if (b.taskId != null) b.taskId!,
    };
    final List<Task> unscheduled = tasks
        .where((Task t) =>
            !blockedTaskIds.contains(t.id) && t.status != TaskStatus.done)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: <Widget>[
        PlannerNavHeader(
          label: DateFormat('EEEE').format(_date),
          sub:
              '${DateFormat('MMMM d').format(_date)}${plannedMinutes > 0 ? ' · ${formatMinutes(plannedMinutes)} planned' : ''}',
          onPrevious: () => setState(
            () => _date = _date.subtract(const Duration(days: 1)),
          ),
          onNext: () =>
              setState(() => _date = _date.add(const Duration(days: 1))),
        ),
        const SizedBox(height: 16),
        _WeekStrip(
          selected: _date,
          onSelect: (DateTime day) => setState(() => _date = day),
        ),
        const SizedBox(height: 16),
        _HourGrid(
          date: _date,
          isToday: _isToday,
          blocks: blocks,
          tasks: tasks,
          firstHour: _firstHour,
          lastHour: _lastHour,
          hourHeight: _hourHeight,
          onBlockTap: (TimeBlock block) {
            // No dedicated block editor — deleting is the design's escape
            // hatch; recreate via a free-slot tap.
            _confirmDeleteBlock(block);
          },
          onFreeSlotTap: (TimeOfDay start) =>
              _showTimeBlockSheet(tasks, initialStart: start),
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text('UNSCHEDULED · TAP TO ADD A TASK', style: lumaEyebrow()),
            Text('${unscheduled.length}',
                style: lumaSans(size: 12, color: LumaColors.ink3)),
          ],
        ),
        const SizedBox(height: 10),
        if (unscheduled.isEmpty)
          GestureDetector(
            onTap: () => _isToday
                ? _showQuickTaskSheet()
                : _showTaskForDateSheet(),
            child: Text('Nothing waiting — tap to capture a task.',
                style: lumaSans(size: 13, color: LumaColors.ink3)),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: <Widget>[
                for (final Task task in unscheduled) ...<Widget>[
                  _UnscheduledChip(
                    title: task.title,
                    onTap: () =>
                        _showTimeBlockSheet(tasks, initialTaskId: task.id),
                  ),
                  const SizedBox(width: 8),
                ],
                _UnscheduledChip(
                  title: 'Add task',
                  icon: LumaIcons.plus,
                  onTap: () => _isToday
                      ? _showQuickTaskSheet()
                      : _showTaskForDateSheet(),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        Text('INTENTION', style: lumaEyebrow()),
        const SizedBox(height: 10),
        plan.when(
          loading: () => const SizedBox(height: 60),
          error: (Object error, _) => Text('Could not load the day plan.',
              style: lumaSans(size: 13, color: LumaColors.ink3)),
          data: (DailyPlan? existing) => PlanTextFieldCard(
            key: ValueKey<String>('intention-$_date-${existing?.id}'),
            label: 'Intention for the day',
            hint: 'What would make today a win?',
            initialValue: existing?.intention,
            onSave: (String value) => _saveIntention(existing, value),
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

  Future<void> _confirmDeleteBlock(TimeBlock block) async {
    final bool? remove = await showAppBottomSheet<bool>(
      context: context,
      title: 'Time block',
      builder: (BuildContext sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          LumaSecondaryButton(
            label: 'Remove from the day',
            onTap: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 10),
          LumaTextButton(
            label: 'Keep it',
            onTap: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (remove ?? false) {
      await ref.read(timeBlockRepositoryProvider).delete(block.id);
    }
  }

  /// Quick task for today via a minimal sheet.
  Future<void> _showQuickTaskSheet() => _showTaskForDateSheet();

  /// Inline task creation for this view's date.
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
            LumaTextField(
              label: 'What needs doing?',
              controller: title,
            ),
            const SizedBox(height: 16),
            LumaPrimaryButton(
              label: 'Save',
              onTap: () async {
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

  Future<void> _showTimeBlockSheet(
    List<Task> dayTasks, {
    TimeOfDay? initialStart,
    String? initialTaskId,
  }) {
    final DateTime date = _date;
    String? taskId = initialTaskId;
    TimeOfDay? start = initialStart;
    TimeOfDay? end = initialStart == null
        ? null
        : TimeOfDay(
            hour: (initialStart.hour + 1).clamp(0, 23),
            minute: initialStart.minute);
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
                  decoration: const InputDecoration(hintText: 'Linked task'),
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
                const SizedBox(height: 12),
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
                    const SizedBox(width: 12),
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
                const SizedBox(height: 16),
                LumaPrimaryButton(
                  label: 'Save',
                  onTap: () async {
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

/// Seven-day strip: weekday letter + date, selected day on an ink pill.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final DateTime monday = mondayOf(selected);
    return Row(
      children: <Widget>[
        for (int i = 0; i < 7; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: Builder(builder: (BuildContext context) {
              final DateTime day = monday.add(Duration(days: i));
              final bool isSelected = day == selected;
              return GestureDetector(
                onTap: () => onSelect(day),
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? LumaColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'MTWTFSS'[i],
                        style: lumaSans(
                          size: 11,
                          color: isSelected
                              ? LumaColors.surface.withValues(alpha: 0.7)
                              : LumaColors.ink3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${day.day}',
                        style: lumaSans(
                          size: 16,
                          weight: FontWeight.w600,
                          color: isSelected
                              ? LumaColors.surface
                              : LumaColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// The hour grid: hairline hour lines with time labels, positioned blocks,
/// and the "now" line in the design's negative red.
class _HourGrid extends StatelessWidget {
  const _HourGrid({
    required this.date,
    required this.isToday,
    required this.blocks,
    required this.tasks,
    required this.firstHour,
    required this.lastHour,
    required this.hourHeight,
    required this.onBlockTap,
    required this.onFreeSlotTap,
  });

  final DateTime date;
  final bool isToday;
  final List<TimeBlock> blocks;
  final List<Task> tasks;
  final int firstHour;
  final int lastHour;
  final double hourHeight;
  final ValueChanged<TimeBlock> onBlockTap;
  final ValueChanged<TimeOfDay> onFreeSlotTap;

  double _yFor(DateTime time) {
    final DateTime local = time.toLocal();
    final double minutes =
        (local.hour - firstHour) * 60.0 + local.minute;
    return minutes / 60.0 * hourHeight;
  }

  @override
  Widget build(BuildContext context) {
    final double height = (lastHour - firstHour) * hourHeight + 20;
    final DateTime now = DateTime.now();
    final Map<String, Task> taskById = <String, Task>{
      for (final Task t in tasks) t.id: t,
    };

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (TapUpDetails details) {
              final double minutes =
                  details.localPosition.dy / hourHeight * 60;
              final int hour =
                  (firstHour + minutes ~/ 60).clamp(firstHour, lastHour - 1);
              final int minute = (minutes % 60) >= 30 ? 30 : 0;
              onFreeSlotTap(TimeOfDay(hour: hour, minute: minute));
            },
            child: Stack(
              children: <Widget>[
                for (int hour = firstHour; hour <= lastHour; hour++)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (hour - firstHour) * hourHeight,
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 38,
                          child: Text(
                            '${hour.toString().padLeft(2, '0')}:00',
                            style: lumaSans(
                                size: 11.5, color: LumaColors.ink3),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: SizedBox(
                            height: 1,
                            child:
                                ColoredBox(color: LumaColors.hairline),
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final TimeBlock block in blocks)
                  if (block.startAt != null && block.endAt != null)
                    Positioned(
                      left: 52,
                      right: 0,
                      top: _yFor(block.startAt!) + 8,
                      height: (block.endAt!
                                      .difference(block.startAt!)
                                      .inMinutes /
                                  60.0 *
                                  hourHeight -
                              4)
                          .clamp(24.0, double.infinity),
                      child: _BlockCard(
                        block: block,
                        task: block.taskId == null
                            ? null
                            : taskById[block.taskId!],
                        current: isToday &&
                            now.isAfter(block.startAt!.toLocal()) &&
                            now.isBefore(block.endAt!.toLocal()),
                        onTap: () => onBlockTap(block),
                      ),
                    ),
                if (isToday &&
                    now.hour >= firstHour &&
                    now.hour < lastHour)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _yFor(now),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 44,
                          child: Text(
                            DateFormat('HH:mm').format(now),
                            style: lumaSans(
                                size: 11,
                                weight: FontWeight.w600,
                                color: LumaColors.negative),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: LumaColors.negative,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Expanded(
                          child: SizedBox(
                            height: 1.5,
                            child:
                                ColoredBox(color: LumaColors.negative),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.block,
    required this.task,
    required this.current,
    required this.onTap,
  });

  final TimeBlock block;
  final Task? task;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool done = task?.status == TaskStatus.done;
    final String range =
        '${DateFormat('HH:mm').format(block.startAt!.toLocal())} – ${DateFormat('HH:mm').format(block.endAt!.toLocal())}';

    final Color background;
    final Color titleColor;
    final Color subColor;
    Border? border;
    if (done) {
      background = LumaColors.sunken;
      titleColor = LumaColors.ink3;
      subColor = LumaColors.ink3;
    } else if (current) {
      background = LumaColors.accent;
      titleColor = LumaColors.surface;
      subColor = LumaColors.surface.withValues(alpha: 0.8);
    } else if (task != null) {
      background = LumaColors.accentSoft;
      titleColor = LumaColors.ink;
      subColor = LumaColors.ink3;
    } else {
      background = Colors.transparent;
      titleColor = LumaColors.ink;
      subColor = LumaColors.ink3;
      border = Border.all(color: LumaColors.ink3);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: background,
          border: border,
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              task?.title ?? 'Time block',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: lumaSans(
                  size: 14, weight: FontWeight.w600, color: titleColor),
            ),
            Text(
              done ? 'Done · $range' : range,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: lumaSans(size: 12, color: subColor),
            ),
          ],
        ),
      ),
    );
  }
}

/// White pill chip for unscheduled tasks (design's drag chips).
class _UnscheduledChip extends StatelessWidget {
  const _UnscheduledChip({
    required this.title,
    required this.onTap,
    this.icon = LumaIcons.ellipsis,
  });

  final String title;
  final VoidCallback onTap;
  final String icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.only(left: 6, right: 12),
        decoration: BoxDecoration(
          color: LumaColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: LumaColors.hairline, offset: Offset(0, 1)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            LumaIcon(icon, size: 16, color: LumaColors.ink3),
            const SizedBox(width: 6),
            Text(title, style: lumaSans(size: 13)),
          ],
        ),
      ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(label,
            style: lumaSans(
                size: 13, weight: FontWeight.w500, color: LumaColors.ink2)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () async {
            final TimeOfDay? picked = await showTimePicker(
              context: context,
              initialTime: value ?? TimeOfDay.now(),
            );
            if (picked != null) onChanged(picked);
          },
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: LumaColors.surface,
              border: Border.all(color: LumaColors.hairline),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  value == null ? '--:--' : value!.format(context),
                  style: lumaSans(size: 15),
                ),
                const LumaIcon(LumaIcons.chevronRight,
                    size: 16, color: LumaColors.ink3),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
