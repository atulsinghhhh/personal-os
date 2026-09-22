import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/repository_providers.dart';
import '../../features/future/domain/entities/future_entities.dart';
import '../../features/goals/domain/entities/goal_entities.dart';
import '../../features/projects/domain/entities/project_entities.dart';
import '../models/money.dart';

/// The core product relationship, resolved for display: a task's (or
/// project's/goal's) full chain up to the future it serves, plus the time
/// and money invested at that level. Rendered by BreadcrumbChain on every
/// detail screen.
class EntityChain {
  const EntityChain({
    this.task,
    this.project,
    this.milestone,
    this.goal,
    this.lifeArea,
    this.vision,
    this.timeInvestedMinutes = 0,
    this.moneyInvested = const <Money>[],
  });

  final Task? task;
  final Project? project;
  final Milestone? milestone;
  final Goal? goal;
  final LifeArea? lifeArea;
  final Vision? vision;
  final int timeInvestedMinutes;
  final List<Money> moneyInvested;
}

Future<EntityChain> _resolveFromProject(
  Ref ref,
  Project? project, {
  Task? task,
  int timeInvestedMinutes = 0,
  List<Money> moneyInvested = const <Money>[],
}) async {
  Milestone? milestone;
  Goal? goal;
  LifeArea? lifeArea;
  Vision? vision;

  if (project?.goalId != null) {
    goal = await ref.read(goalRepositoryProvider).getById(project!.goalId!);
  }
  if (project?.milestoneId != null && goal != null) {
    final List<Milestone> milestones = await ref
        .read(goalRepositoryProvider)
        .watchMilestones(goal.id)
        .first;
    for (final Milestone candidate in milestones) {
      if (candidate.id == project!.milestoneId) milestone = candidate;
    }
  }
  if (goal?.lifeAreaId != null) {
    lifeArea =
        await ref.read(lifeAreaRepositoryProvider).getById(goal!.lifeAreaId!);
  }
  if (goal?.visionId != null) {
    vision = await ref.read(visionRepositoryProvider).getById(goal!.visionId!);
  }

  return EntityChain(
    task: task,
    project: project,
    milestone: milestone,
    goal: goal,
    lifeArea: lifeArea,
    vision: vision,
    timeInvestedMinutes: timeInvestedMinutes,
    moneyInvested: moneyInvested,
  );
}

final chainForTaskProvider =
    FutureProvider.family<EntityChain, String>((Ref ref, String taskId) async {
  final Task? task = await ref.read(taskRepositoryProvider).getById(taskId);
  if (task == null) return const EntityChain();

  Project? project;
  if (task.projectId != null) {
    project =
        await ref.read(projectRepositoryProvider).getById(task.projectId!);
  }
  final int minutes = await ref
      .read(focusSessionRepositoryProvider)
      .totalMinutesForTask(taskId);

  return _resolveFromProject(
    ref,
    project,
    task: task,
    timeInvestedMinutes: minutes,
  );
});

final chainForProjectProvider =
    FutureProvider.family<EntityChain, String>((
  Ref ref,
  String projectId,
) async {
  final Project? project =
      await ref.read(projectRepositoryProvider).getById(projectId);
  if (project == null) return const EntityChain();

  final int minutes = await ref
      .read(focusSessionRepositoryProvider)
      .totalMinutesForProject(projectId);
  final List<Money> money = await ref
      .read(transactionRepositoryProvider)
      .totalSpentForProject(projectId);

  return _resolveFromProject(
    ref,
    project,
    timeInvestedMinutes: minutes,
    moneyInvested: money,
  );
});

final chainForGoalProvider =
    FutureProvider.family<EntityChain, String>((Ref ref, String goalId) async {
  final Goal? goal = await ref.read(goalRepositoryProvider).getById(goalId);
  if (goal == null) return const EntityChain();

  LifeArea? lifeArea;
  Vision? vision;
  if (goal.lifeAreaId != null) {
    lifeArea =
        await ref.read(lifeAreaRepositoryProvider).getById(goal.lifeAreaId!);
  }
  if (goal.visionId != null) {
    vision = await ref.read(visionRepositoryProvider).getById(goal.visionId!);
  }

  final int minutes = await ref
      .read(focusSessionRepositoryProvider)
      .totalMinutesForGoal(goalId);
  final List<Money> money =
      await ref.read(transactionRepositoryProvider).totalSpentForGoal(goalId);

  return EntityChain(
    goal: goal,
    lifeArea: lifeArea,
    vision: vision,
    timeInvestedMinutes: minutes,
    moneyInvested: money,
  );
});
