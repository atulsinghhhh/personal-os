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
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/goal_entities.dart';

/// Design 17 "Goal detail": serif headline metric with a progress line,
/// the goal's "why", a milestone timeline and what moves the goal.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForGoalProvider(goalId));
    final List<Milestone> milestones =
        ref.watch(_milestonesProvider(goalId)).value ?? const <Milestone>[];
    final List<Project> projects =
        ref.watch(_projectsProvider(goalId)).value ?? const <Project>[];
    final List<GoalMetric> metrics =
        ref.watch(_metricsProvider(goalId)).value ?? const <GoalMetric>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => const Center(
            child: ErrorStateView(message: 'Could not load this goal.')),
        data: (EntityChain data) {
          final Goal? goal = data.goal;
          if (goal == null) {
            return const Center(
                child: EmptyStateView(message: 'Goal not found.'));
          }

          final GoalMetric? metric = metrics
              .where((GoalMetric m) =>
                  m.targetValue != null && m.targetValue! > 0)
              .firstOrNull;
          final double? progress = metric == null
              ? null
              : (metric.currentValue / metric.targetValue!).clamp(0.0, 1.0);

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
              Text(
                  '${data.lifeArea?.name.toUpperCase() ?? 'LIFE'} · GOAL',
                  style: lumaEyebrow()),
              const SizedBox(height: 8),
              Text(goal.title, style: lumaSerif(size: 36, height: 1.05)),
              if (metric != null) ...<Widget>[
                const SizedBox(height: 28),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Text(_fmtMetric(metric, metric.currentValue),
                        style: lumaSerif(size: 50, height: 1)),
                    const SizedBox(width: 10),
                    Text('of ${_fmtMetric(metric, metric.targetValue!)}',
                        style: lumaSans(size: 14, color: LumaColors.ink3)),
                  ],
                ),
                const SizedBox(height: 12),
                LumaProgressLine(value: progress!, height: 6),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      goal.targetDate == null
                          ? '${(progress * 100).round()}%'
                          : '${(progress * 100).round()}% · Target ${DateFormat('MMM yyyy').format(goal.targetDate!.toLocal())}',
                      style: lumaSans(size: 13, color: LumaColors.ink2),
                    ),
                    if (goal.status == GoalStatus.active)
                      Text('On track',
                          style: lumaSans(
                              size: 13,
                              weight: FontWeight.w500,
                              color: LumaColors.positive)),
                  ],
                ),
              ],
              if (goal.description != null &&
                  goal.description!.isNotEmpty) ...<Widget>[
                const SizedBox(height: 28),
                const LumaEyebrow('Why'),
                const SizedBox(height: 12),
                Text(goal.description!,
                    style: lumaSerif(
                        size: 21, height: 1.35, style: FontStyle.italic)),
              ],
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const LumaEyebrow('Milestones'),
                  GestureDetector(
                    onTap: () =>
                        showMilestoneSheet(context, ref, goalId: goalId),
                    child: Text('Add',
                        style: lumaSans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: LumaColors.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (milestones.isEmpty)
                Text('No milestones yet.',
                    style: lumaSans(size: 13, color: LumaColors.ink3))
              else
                for (int i = 0; i < milestones.length; i++)
                  _MilestoneRow(
                    milestone: milestones[i],
                    last: i == milestones.length - 1,
                    onToggle: () =>
                        ref.read(goalRepositoryProvider).updateMilestone(
                              milestones[i].copyWith(
                                status: milestones[i].status ==
                                        MilestoneStatus.done
                                    ? MilestoneStatus.pending
                                    : MilestoneStatus.done,
                                updatedAt: DateTime.now().toUtc(),
                              ),
                            ),
                  ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const LumaEyebrow('What moves this goal'),
                  GestureDetector(
                    onTap: () =>
                        showProjectSheet(context, ref, goalId: goalId),
                    child: Text('New project',
                        style: lumaSans(
                            size: 13,
                            weight: FontWeight.w500,
                            color: LumaColors.accent)),
                  ),
                ],
              ),
              if (projects.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Text('No projects driving this goal yet.',
                      style: lumaSans(size: 13, color: LumaColors.ink3)),
                )
              else
                for (final Project project in projects)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go('/future/project/${project.id}'),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 58),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: LumaColors.hairline)),
                      ),
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 62,
                            child: Text('PROJECT',
                                style: lumaSans(
                                    size: 11,
                                    color: LumaColors.ink3,
                                    letterSpacing: 11 * 0.06)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(project.title,
                                    style: lumaSans(
                                        size: 15,
                                        weight: FontWeight.w500)),
                                if (project.description != null &&
                                    project.description!.isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 2),
                                  Text(project.description!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: lumaSans(
                                          size: 12.5,
                                          color: LumaColors.ink3)),
                                ],
                              ],
                            ),
                          ),
                          const LumaIcon(LumaIcons.chevronRight,
                              size: 16, color: LumaColors.ink3),
                        ],
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  static String _fmtMetric(GoalMetric metric, double value) {
    final String formatted = NumberFormat('#,##0').format(value);
    final String unit = metric.unit ?? '';
    if (unit.isEmpty) return formatted;
    // Currency-style units read best as a prefix (₹7,40,000); words as
    // a suffix (12 books).
    if (unit.length <= 2 && !RegExp(r'[a-zA-Z]').hasMatch(unit)) {
      return '$unit$formatted';
    }
    return '$formatted $unit';
  }
}

/// One milestone on the design's vertical check timeline.
class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({
    required this.milestone,
    required this.last,
    required this.onToggle,
  });

  final Milestone milestone;
  final bool last;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final bool done = milestone.status == MilestoneStatus.done;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 58),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Column(
              children: <Widget>[
                GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: done
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: LumaColors.ink,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: LumaIcon(LumaIcons.check,
                                size: 12,
                                color: LumaColors.surface,
                                strokeWidth: 2.4),
                          ),
                        )
                      : Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: LumaColors.hairline, width: 1.5),
                          ),
                        ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: done ? LumaColors.ink : LumaColors.hairline,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(milestone.title,
                      style: lumaSans(
                          size: 15,
                          weight: FontWeight.w500,
                          color:
                              done ? LumaColors.ink : LumaColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    milestone.targetDate == null
                        ? (done ? 'Done' : 'No date')
                        : DateFormat('MMM yyyy')
                            .format(milestone.targetDate!.toLocal()),
                    style: lumaSans(size: 12.5, color: LumaColors.ink3),
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _milestonesProvider = StreamProvider.family<List<Milestone>, String>((
  Ref ref,
  String goalId,
) {
  return ref.watch(goalRepositoryProvider).watchMilestones(goalId);
});

final _projectsProvider = StreamProvider.family<List<Project>, String>((
  Ref ref,
  String goalId,
) {
  return ref.watch(projectRepositoryProvider).watchByGoal(goalId);
});

final _metricsProvider = StreamProvider.family<List<GoalMetric>, String>((
  Ref ref,
  String goalId,
) {
  return ref.watch(goalRepositoryProvider).watchMetrics(goalId);
});
