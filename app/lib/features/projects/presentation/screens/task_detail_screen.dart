import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../domain/entities/project_entities.dart';

/// Design 10 "Task detail": breadcrumb chain, big serif title with a
/// completion circle, hairline meta rows, notes, time progress and a pinned
/// "Start focus" bar.
class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForTaskProvider(taskId));

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            const Center(child: ErrorStateView(message: 'Could not load this task.')),
        data: (EntityChain data) {
          final Task? task = data.task;
          if (task == null) {
            return const Center(child: EmptyStateView(message: 'Task not found.'));
          }
          return _TaskDetailBody(taskId: taskId, chain: data, task: task);
        },
      ),
    );
  }
}

class _TaskDetailBody extends ConsumerWidget {
  const _TaskDetailBody({
    required this.taskId,
    required this.chain,
    required this.task,
  });

  final String taskId;
  final EntityChain chain;
  final Task task;

  void _update(WidgetRef ref, Task updated) {
    ref.read(taskRepositoryProvider).update(updated);
    ref.invalidate(chainForTaskProvider(taskId));
  }

  Future<void> _pickDate(
    BuildContext context,
    WidgetRef ref, {
    required DateTime? current,
    required Task Function(DateTime) apply,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: current?.toLocal() ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      _update(
          ref, apply(DateTime.utc(picked.year, picked.month, picked.day)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool done = task.status == TaskStatus.done;
    final List<String> crumbs = <String>[
      if (chain.goal != null) chain.goal!.title
      else if (chain.vision != null) chain.vision!.title,
      if (chain.project != null) chain.project!.title,
      if (chain.milestone != null) chain.milestone!.title,
    ];
    final int? estimate = task.estimateMinutes;

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 140),
            children: <Widget>[
              SizedBox(
                height: 44,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(RoutePaths.today),
                      child: Row(
                        children: <Widget>[
                          const LumaIcon(LumaIcons.chevronLeft,
                              size: 22, color: LumaColors.ink2),
                          const SizedBox(width: 2),
                          Text('Back',
                              style: lumaSans(
                                  size: 15, color: LumaColors.ink2)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: LumaIcon(LumaIcons.ellipsis,
                            size: 21, color: LumaColors.ink2),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (crumbs.isNotEmpty) ...<Widget>[
                LumaBreadcrumb(crumbs),
                const SizedBox(height: 14),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: LumaCheckbox(
                      checked: done,
                      semanticLabel: 'Complete task',
                      onTap: () => _update(
                        ref,
                        task.copyWith(
                          status:
                              done ? TaskStatus.todo : TaskStatus.done,
                          updatedAt: DateTime.now().toUtc(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      task.title,
                      style: lumaSerif(size: 36, height: 1.05).copyWith(
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                        decorationColor: LumaColors.ink3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              LumaMetaRow(
                label: 'Project',
                hairlineTop: false,
                value: chain.project?.title ?? '—',
                onTap: chain.project == null
                    ? null
                    : () => context.go(
                        '${RoutePaths.future}/project/${chain.project!.id}'),
              ),
              LumaMetaRow(
                label: 'Scheduled',
                value: task.scheduledDate == null
                    ? 'Not set'
                    : DateFormat('EEE, MMM d')
                        .format(task.scheduledDate!.toLocal()),
                onTap: () => _pickDate(
                  context,
                  ref,
                  current: task.scheduledDate,
                  apply: (DateTime d) => task.copyWith(
                      scheduledDate: d, updatedAt: DateTime.now().toUtc()),
                ),
              ),
              LumaMetaRow(
                label: 'Due',
                value: task.dueDate == null
                    ? 'Not set'
                    : DateFormat('EEE, MMM d')
                        .format(task.dueDate!.toLocal()),
                onTap: () => _pickDate(
                  context,
                  ref,
                  current: task.dueDate,
                  apply: (DateTime d) => task.copyWith(
                      dueDate: d, updatedAt: DateTime.now().toUtc()),
                ),
              ),
              LumaMetaRow(
                label: 'Estimate',
                value: estimate == null ? '—' : _fmtMinutes(estimate),
              ),
              LumaMetaRow(
                label: 'Priority',
                valueWidget: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (task.priority >= 2) ...<Widget>[
                      const LumaIcon(LumaIcons.flag,
                          size: 15, color: LumaColors.negative),
                      const SizedBox(width: 6),
                    ],
                    Text(_priorityLabel(task.priority),
                        style: lumaSans(size: 14, weight: FontWeight.w500)),
                  ],
                ),
              ),
              if (chain.goal != null)
                LumaMetaRow(
                  label: 'Goal',
                  value: chain.goal!.title,
                  onTap: () => context
                      .go('${RoutePaths.future}/goal/${chain.goal!.id}'),
                ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const LumaIcon(LumaIcons.plus,
                      size: 16, color: LumaColors.accent),
                  const SizedBox(width: 6),
                  Text('Add tag, repeat, reminder or cost',
                      style: lumaSans(
                          size: 14,
                          weight: FontWeight.w500,
                          color: LumaColors.accent)),
                ],
              ),
              const SizedBox(height: 28),
              _BlockedBySection(taskId: taskId),
              if (task.notes != null && task.notes!.isNotEmpty) ...<Widget>[
                const LumaSectionHeader('Notes'),
                const SizedBox(height: 12),
                Text(task.notes!,
                    style: lumaSans(
                        size: 15, height: 1.55, color: LumaColors.ink2)),
                const SizedBox(height: 28),
              ],
              const LumaSectionHeader('Time'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('${_fmtMinutes(task.actualMinutes)} logged',
                      style: lumaSans(size: 13, color: LumaColors.ink2)),
                  if (estimate != null)
                    Text('of ${_fmtMinutes(estimate)}',
                        style: lumaSans(size: 13, color: LumaColors.ink2)),
                ],
              ),
              const SizedBox(height: 8),
              LumaProgressLine(
                value: estimate == null || estimate == 0
                    ? 0
                    : task.actualMinutes / estimate,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, 30 + MediaQuery.paddingOf(context).bottom),
            decoration: const BoxDecoration(
              color: LumaColors.ground,
              border: Border(top: BorderSide(color: LumaColors.hairline)),
            ),
            child: LumaPrimaryButton(
              label: 'Start focus · 50 min',
              height: 52,
              leading: const LumaPlayIcon(size: 16),
              onTap: () => context.go('/future/task/$taskId/focus'),
            ),
          ),
        ),
      ],
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

String _priorityLabel(int priority) => switch (priority) {
      <= 0 => 'None',
      1 => 'Low',
      2 => 'Medium',
      _ => 'High',
    };

/// Shows which still-open tasks this one depends on ("Blocked by").
class _BlockedBySection extends ConsumerWidget {
  const _BlockedBySection({required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Task>> blockers =
        ref.watch(_blockingTasksProvider(taskId));

    return blockers.when(
      loading: () => const SizedBox.shrink(),
      error: (Object e, _) => const SizedBox.shrink(),
      data: (List<Task> tasks) {
        final List<Task> open = tasks
            .where((Task t) => t.status != TaskStatus.done)
            .toList(growable: false);
        if (open.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: LumaColors.negative.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const LumaIcon(LumaIcons.flag,
                        size: 15, color: LumaColors.negative),
                    const SizedBox(width: 8),
                    Text('BLOCKED BY',
                        style: lumaEyebrow(color: LumaColors.negative)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final Task blocker in open)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(blocker.title, style: lumaSans(size: 14)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Resolves this task's dependency links to the actual blocking tasks.
final _blockingTasksProvider =
    StreamProvider.family<List<Task>, String>((Ref ref, String taskId) {
  return ref
      .watch(taskRepositoryProvider)
      .watchDependencies(taskId)
      .asyncMap((List<TaskDependency> dependencies) async {
    final List<Task> blockers = <Task>[];
    for (final TaskDependency dependency in dependencies) {
      final Task? task = await ref
          .read(taskRepositoryProvider)
          .getById(dependency.dependsOnTaskId);
      if (task != null && task.deletedAt == null) blockers.add(task);
    }
    return blockers;
  });
});
