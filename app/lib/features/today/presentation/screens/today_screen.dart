import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../core/sync/connectivity_service.dart';
import '../../../../core/sync/sync_providers.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/luma_tab_bar.dart' show LumaFab;
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
import '../../../../shared/models/money.dart';
import '../../../../shared/models/profile.dart';
import '../../../calendar/domain/entities/calendar_entities.dart';
import '../../../capture/presentation/quick_capture_sheet.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../providers/today_providers.dart';

/// Design 08 "Today" — the home command center: greeting, the hero "Now"
/// block, the day timeline, anytime tasks and today-so-far stats.
/// Everything reads from local Drift streams, so this screen renders
/// instantly with no network.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> tasksAsync = ref.watch(todayTasksProvider);
    final List<TimeBlock> blocks =
        ref.watch(todayTimeBlocksProvider).value ?? const <TimeBlock>[];
    final bool isOnline = ref.watch(isOnlineProvider).value ?? true;
    final int conflictCount = ref.watch(conflictCountProvider).value ?? 0;

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (!isOnline) const OfflineBanner(),
                  if (conflictCount > 0)
                    ConflictBanner(count: conflictCount, onTap: () {}),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref.read(syncEngineProvider).kick(),
                      child: tasksAsync.when(
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (Object error, _) => const Center(
                            child:
                                ErrorStateView(message: 'Could not load tasks.')),
                        data: (List<Task> tasks) => _TodayBody(
                          tasks: tasks,
                          blocks: blocks,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 20,
            child: LumaFab(onTap: () => showQuickCaptureSheet(context)),
          ),
        ],
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.tasks, required this.blocks});

  final List<Task> tasks;
  final List<TimeBlock> blocks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Profile? profile = ref.watch(currentProfileProvider).value;
    final Map<String, Task> taskById = <String, Task>{
      for (final Task t in tasks) t.id: t,
    };
    final List<TimeBlock> sortedBlocks = <TimeBlock>[...blocks]..sort(
        (TimeBlock a, TimeBlock b) => (a.startAt ?? a.date)
            .compareTo(b.startAt ?? b.date));

    final List<Task> open = tasks
        .where((Task t) => t.status != TaskStatus.done)
        .toList(growable: false);
    final Task? hero = open.isEmpty ? null : open.first;
    final TimeBlock? heroBlock = hero == null
        ? null
        : sortedBlocks
            .where((TimeBlock b) => b.taskId == hero.id)
            .firstOrNull;

    final Set<String> blockedTaskIds = <String>{
      for (final TimeBlock b in sortedBlocks)
        if (b.taskId != null) b.taskId!,
    };
    final List<Task> anytime = tasks
        .where((Task t) => !blockedTaskIds.contains(t.id))
        .toList(growable: false);

    final DateTime now = DateTime.now();
    final String greeting = switch (now.hour) {
      < 12 => 'Good morning',
      < 17 => 'Good afternoon',
      _ => 'Good evening',
    };
    final String name = profile?.displayName ?? '';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(DateFormat('EEEE, MMMM d').format(now),
                style: lumaSans(
                    size: 13,
                    weight: FontWeight.w500,
                    color: LumaColors.ink2)),
            Transform.translate(
              offset: const Offset(10, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const <Widget>[
                  _HeaderIcon(LumaIcons.search, label: 'Search'),
                  _HeaderIcon(LumaIcons.bell, label: 'Notifications'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(name.isEmpty ? greeting : '$greeting, $name',
            style: lumaSerif(size: 40, height: 1.05)),
        const SizedBox(height: 10),
        Text(
          hero == null
              ? 'Nothing scheduled yet. Capture one important thing for today.'
              : '${open.length} ${open.length == 1 ? 'task' : 'tasks'} left today. Your one important thing is ${hero.title}.',
          style: lumaSans(size: 15, height: 1.45, color: LumaColors.ink2),
        ),
        const SizedBox(height: 28),
        if (hero != null) ...<Widget>[
          _NowCard(task: hero, block: heroBlock),
          const SizedBox(height: 28),
        ],
        LumaSectionHeader('Your day',
            action: 'Open planner',
            onAction: () => context.go(RoutePaths.plan)),
        const SizedBox(height: 16),
        if (sortedBlocks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('No time blocks yet — plan your day to see it here.',
                style: lumaSans(size: 13, color: LumaColors.ink3)),
          )
        else
          ..._timeline(context, sortedBlocks, taskById, now),
        const SizedBox(height: 28),
        LumaSectionHeader('Anytime today · ${anytime.length}'),
        const SizedBox(height: 4),
        if (anytime.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Nothing here — capture a task to get started.',
                style: lumaSans(size: 13, color: LumaColors.ink3)),
          )
        else
          for (int i = 0; i < anytime.length; i++)
            LumaTaskRow(
              title: anytime[i].title,
              trailing: anytime[i].estimateMinutes == null
                  ? null
                  : _fmtMinutes(anytime[i].estimateMinutes!),
              checked: anytime[i].status == TaskStatus.done,
              hairlineTop: i > 0,
              onToggle: () => _toggle(ref, anytime[i]),
            ),
        const SizedBox(height: 28),
        const LumaSectionHeader('Today so far'),
        const SizedBox(height: 12),
        _TodayStats(tasks: tasks),
      ],
    );
  }

  List<Widget> _timeline(
    BuildContext context,
    List<TimeBlock> blocks,
    Map<String, Task> taskById,
    DateTime now,
  ) {
    final List<Widget> rows = <Widget>[];
    bool nowInserted = false;

    for (int i = 0; i < blocks.length; i++) {
      final TimeBlock block = blocks[i];
      final DateTime start = block.startAt?.toLocal() ?? block.date.toLocal();
      final Task? task = block.taskId == null ? null : taskById[block.taskId!];
      final bool done = task?.status == TaskStatus.done;
      final bool current = block.startAt != null &&
          block.endAt != null &&
          now.isAfter(block.startAt!.toLocal()) &&
          now.isBefore(block.endAt!.toLocal());

      if (!nowInserted && now.isBefore(start) && i > 0) {
        nowInserted = true;
        rows.add(_nowLine(now));
      }

      final String sub = block.startAt != null && block.endAt != null
          ? (done
              ? 'Done · ${_fmtMinutes(block.endAt!.difference(block.startAt!).inMinutes)}'
              : _fmtMinutes(block.endAt!.difference(block.startAt!).inMinutes))
          : '';

      rows.add(_TimelineEntry(
        time: DateFormat('HH:mm').format(start),
        dot: done
            ? LumaDotStyle.filledMuted
            : current
                ? LumaDotStyle.filledAccent
                : LumaDotStyle.outlined,
        title: task?.title ?? 'Time block',
        titleStyle: done
            ? lumaSans(
                    size: 15,
                    weight: FontWeight.w500,
                    color: LumaColors.ink3)
                .copyWith(
                    decoration: TextDecoration.lineThrough,
                    decorationColor: LumaColors.ink3)
            : current
                ? lumaSans(
                    size: 15,
                    weight: FontWeight.w500,
                    color: LumaColors.accent)
                : null,
        sub: sub,
        last: i == blocks.length - 1,
        onTap: task == null
            ? null
            : () => context.go('${RoutePaths.future}/task/${task.id}'),
      ));

      if (!nowInserted && current) {
        nowInserted = true;
        rows.add(_nowLine(now));
      }
    }
    return rows;
  }

  Widget _nowLine(DateTime now) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 40,
            child: Text(DateFormat('HH:mm').format(now),
                style: lumaSans(
                    size: 11,
                    weight: FontWeight.w600,
                    color: LumaColors.accent)),
          ),
          const Expanded(
              child: SizedBox(
                  height: 1.5,
                  child: ColoredBox(color: LumaColors.accent))),
          const SizedBox(width: 8),
          Text('now',
              style: lumaSans(
                  size: 11,
                  weight: FontWeight.w500,
                  color: LumaColors.accent)),
        ],
      ),
    );
  }

  void _toggle(WidgetRef ref, Task task) {
    final bool done = task.status == TaskStatus.done;
    ref.read(taskRepositoryProvider).update(
          task.copyWith(
            status: done ? TaskStatus.todo : TaskStatus.done,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }
}

class _NowCard extends ConsumerWidget {
  const _NowCard({required this.task, this.block});

  final Task task;
  final TimeBlock? block;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Project? project = task.projectId == null
        ? null
        : ref.watch(_projectByIdProvider(task.projectId!)).value;

    final String eyebrow;
    if (block?.startAt != null && block?.endAt != null) {
      final DateFormat f = DateFormat('HH:mm');
      eyebrow =
          'NOW · ${f.format(block!.startAt!.toLocal())} – ${f.format(block!.endAt!.toLocal())}';
    } else {
      eyebrow = 'NEXT UP';
    }

    final int? estimate = task.estimateMinutes;
    final double progress =
        estimate == null || estimate == 0 ? 0 : task.actualMinutes / estimate;

    return LumaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: LumaColors.accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(eyebrow, style: lumaEyebrow(color: LumaColors.accent)),
            ],
          ),
          const SizedBox(height: 14),
          Text(task.title, style: lumaSerif(size: 30, height: 1.08)),
          if (project != null) ...<Widget>[
            const SizedBox(height: 14),
            LumaBreadcrumb(<String>[project.title]),
          ],
          if (estimate != null) ...<Widget>[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                    '${_fmtMinutes(task.actualMinutes)} of ${_fmtMinutes(estimate)}',
                    style: lumaSans(size: 12.5, color: LumaColors.ink2)),
              ],
            ),
            const SizedBox(height: 8),
            LumaProgressLine(value: progress),
          ],
          const SizedBox(height: 20),
          Row(
            children: <Widget>[
              Expanded(
                child: LumaPrimaryButton(
                  label: 'Start focus',
                  height: 50,
                  leading: const LumaPlayIcon(size: 16),
                  onTap: () => context
                      .go('${RoutePaths.future}/task/${task.id}/focus'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 96,
                child: LumaSecondaryButton(
                  label: 'Details',
                  background: Colors.transparent,
                  onTap: () =>
                      context.go('${RoutePaths.future}/task/${task.id}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayStats extends ConsumerWidget {
  const _TodayStats({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final int focusMinutes = ref.watch(todayFocusMinutesProvider).value ?? 0;
    final List<Money> spent =
        ref.watch(todaySpentProvider).value ?? const <Money>[];

    final int total = tasks.length;
    final int done =
        tasks.where((Task t) => t.status == TaskStatus.done).length;

    return Row(
      children: <Widget>[
        Expanded(
            child: _Stat(value: '$done', muted: ' / $total', label: 'tasks')),
        Expanded(
            child: _Stat(value: _fmtMinutes(focusMinutes), label: 'focused')),
        Expanded(
          child: _Stat(
            value: spent.isEmpty
                ? '—'
                : NumberFormat.simpleCurrency(
                        name: spent.first.currency, decimalDigits: 0)
                    .format(spent.first.amount),
            label: 'spent',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.muted});
  final String value;
  final String label;
  final String? muted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text.rich(
          TextSpan(
            style: lumaSerif(size: 30),
            children: <InlineSpan>[
              TextSpan(text: value),
              if (muted != null)
                TextSpan(
                    text: muted,
                    style: lumaSerif(size: 30, color: LumaColors.ink3)),
            ],
          ),
        ),
        Text(label, style: lumaSans(size: 12.5, color: LumaColors.ink3)),
      ],
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(this.icon, {required this.label});
  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: LumaIcon(icon, size: 21, color: LumaColors.ink2),
        ),
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.time,
    required this.dot,
    required this.title,
    required this.sub,
    this.titleStyle,
    this.last = false,
    this.onTap,
  });

  final String time;
  final LumaDotStyle dot;
  final String title;
  final String sub;
  final TextStyle? titleStyle;
  final bool last;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: 40,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(time,
                      style: lumaSans(size: 12, color: LumaColors.ink3)),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 14,
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 4),
                    LumaTimelineDot(dot),
                    if (!last) ...<Widget>[
                      const SizedBox(height: 6),
                      Expanded(
                          child:
                              Container(width: 1, color: LumaColors.hairline)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(title,
                          style: titleStyle ??
                              lumaSans(size: 15, weight: FontWeight.w500)),
                      if (sub.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(sub,
                            style:
                                lumaSans(size: 12.5, color: LumaColors.ink3)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtMinutes(int minutes) {
  final int h = minutes ~/ 60;
  final int m = minutes % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

final _projectByIdProvider =
    FutureProvider.family<Project?, String>((Ref ref, String id) {
  return ref.watch(projectRepositoryProvider).getById(id);
});
