import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../../future/presentation/widgets/edit_sheets.dart';
import '../../domain/entities/project_entities.dart';

/// Design 18 "Project detail": breadcrumb chain, serif title with a big
/// accent completion figure, status facts grid, and task rows with the
/// design's status circles.
class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForProjectProvider(projectId));
    final List<Task> tasks =
        ref.watch(_tasksProvider(projectId)).value ?? const <Task>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => const Center(
            child: ErrorStateView(message: 'Could not load this project.')),
        data: (EntityChain data) {
          final Project? project = data.project;
          if (project == null) {
            return const Center(
                child: EmptyStateView(message: 'Project not found.'));
          }

          final int done =
              tasks.where((Task t) => t.status == TaskStatus.done).length;
          final int open = tasks.length - done;
          final int percent =
              tasks.isEmpty ? 0 : (done / tasks.length * 100).round();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
            children: <Widget>[
              SizedBox(
                height: 44,
                child: Row(
                  children: <Widget>[
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go(RoutePaths.future),
                      child: Row(
                        children: <Widget>[
                          const LumaIcon(LumaIcons.chevronLeft,
                              size: 22, color: LumaColors.ink2),
                          const SizedBox(width: 2),
                          Text('Future',
                              style:
                                  lumaSans(size: 15, color: LumaColors.ink2)),
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
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: <Widget>[
                  const LumaIcon(LumaIcons.link,
                      size: 13, color: LumaColors.ink3),
                  Text('My future',
                      style: lumaSans(size: 12, color: LumaColors.ink3)),
                  if (data.goal != null) ...<Widget>[
                    Text('/',
                        style:
                            lumaSans(size: 12, color: LumaColors.hairline)),
                    Text(data.goal!.title,
                        style: lumaSans(size: 12, color: LumaColors.ink3)),
                  ],
                  Text('/',
                      style: lumaSans(size: 12, color: LumaColors.hairline)),
                  Text(project.title,
                      style: lumaSans(size: 12, color: LumaColors.ink3)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(project.title,
                            style: lumaSerif(size: 44, height: 1.05)),
                        if (project.description != null &&
                            project.description!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(project.description!,
                              style: lumaSans(
                                  size: 15, color: LumaColors.ink2)),
                        ],
                      ],
                    ),
                  ),
                  Text('$percent%',
                      style: lumaSerif(
                          size: 44, height: 1, color: LumaColors.accent)),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: LumaColors.hairline),
                    bottom: BorderSide(color: LumaColors.hairline),
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _Fact(
                        label: 'Status',
                        child: Row(
                          children: <Widget>[
                            _StatusCircle(
                                status: project.status ==
                                        ProjectStatus.completed
                                    ? _TaskCircle.done
                                    : _TaskCircle.inProgress),
                            const SizedBox(width: 6),
                            Text(_statusLabel(project.status),
                                style: lumaSans(
                                    size: 15, weight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _Fact(
                        label: 'Goal',
                        child: Text(
                          data.goal?.title ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              lumaSans(size: 15, weight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  LumaEyebrow('Tasks · $open open'),
                  GestureDetector(
                    onTap: () =>
                        showTaskSheet(context, ref, projectId: projectId),
                    child: Text('Add task',
                        style: lumaSans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: LumaColors.accent)),
                  ),
                ],
              ),
              if (tasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text('No tasks in this project yet.',
                      style: lumaSans(size: 13, color: LumaColors.ink3)),
                )
              else
                for (final Task task in tasks)
                  _TaskRow(
                    task: task,
                    onOpen: () => context.go('/future/task/${task.id}'),
                    onToggle: () => ref.read(taskRepositoryProvider).update(
                          task.copyWith(
                            status: task.status == TaskStatus.done
                                ? TaskStatus.todo
                                : TaskStatus.done,
                            updatedAt: DateTime.now().toUtc(),
                          ),
                        ),
                  ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.only(top: 18),
                decoration: const BoxDecoration(
                  border:
                      Border(top: BorderSide(color: LumaColors.hairline)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const LumaEyebrow('Time invested'),
                          const SizedBox(height: 6),
                          Text(_fmtHours(data.timeInvestedMinutes),
                              style: lumaSerif(size: 38, height: 1)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const LumaEyebrow('Money invested'),
                          const SizedBox(height: 6),
                          Text(
                            data.moneyInvested.isEmpty
                                ? '—'
                                : NumberFormat.simpleCurrency(
                                        name: data
                                            .moneyInvested.first.currency,
                                        decimalDigits: 0)
                                    .format(
                                        data.moneyInvested.first.amount),
                            style: lumaSerif(size: 38, height: 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static String _statusLabel(ProjectStatus status) => switch (status) {
        ProjectStatus.active => 'In progress',
        ProjectStatus.completed => 'Completed',
        _ => status.name[0].toUpperCase() + status.name.substring(1),
      };

  static String _fmtHours(int minutes) {
    if (minutes == 0) return '—';
    final int h = minutes ~/ 60;
    return h > 0 ? '${h}h' : '${minutes}m';
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LumaEyebrow(label),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

enum _TaskCircle { todo, inProgress, done }

/// The design's 18px task status circle: outline, half-filled, or filled
/// with a check.
class _StatusCircle extends StatelessWidget {
  const _StatusCircle({required this.status});
  final _TaskCircle status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case _TaskCircle.todo:
        return Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: LumaColors.ink3, width: 1.6),
          ),
        );
      case _TaskCircle.inProgress:
        return SizedBox(
          width: 18,
          height: 18,
          child: CustomPaint(painter: _HalfCirclePainter()),
        );
      case _TaskCircle.done:
        return Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: LumaColors.ink3,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: LumaIcon(LumaIcons.check,
                size: 11, color: LumaColors.surface, strokeWidth: 1.8),
          ),
        );
    }
  }
}

class _HalfCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2 - 1;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = LumaColors.accent,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.5),
      -1.5708,
      3.14159,
      true,
      Paint()..color = LumaColors.accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onOpen,
    required this.onToggle,
  });

  final Task task;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final bool done = task.status == TaskStatus.done;
    final String when = task.scheduledDate == null
        ? ''
        : DateFormat('MMM d').format(task.scheduledDate!.toLocal());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LumaColors.hairline)),
        ),
        child: Row(
          children: <Widget>[
            GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: _StatusCircle(
                    status: done
                        ? _TaskCircle.done
                        : task.actualMinutes > 0
                            ? _TaskCircle.inProgress
                            : _TaskCircle.todo),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: lumaSans(
                    size: 15,
                    color: done ? LumaColors.ink3 : LumaColors.ink),
              ),
            ),
            Text(done ? 'Done' : when,
                style: lumaSans(size: 12.5, color: LumaColors.ink3)),
            if (task.priority >= 3) ...<Widget>[
              const SizedBox(width: 4),
              Text('HIGH',
                  style: lumaSans(
                      size: 11,
                      weight: FontWeight.w600,
                      color: LumaColors.negative)),
            ],
          ],
        ),
      ),
    );
  }
}

final _tasksProvider = StreamProvider.family<List<Task>, String>((
  Ref ref,
  String projectId,
) {
  return ref.watch(taskRepositoryProvider).watchByProject(projectId);
});
