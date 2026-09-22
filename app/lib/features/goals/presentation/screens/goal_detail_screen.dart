import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../../../shared/widgets/breadcrumb_chain.dart';
import '../../../future/presentation/widgets/edit_sheets.dart';
import '../../../projects/domain/entities/project_entities.dart';
import '../../domain/entities/goal_entities.dart';

class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForGoalProvider(goalId));
    final AsyncValue<List<Milestone>> milestones =
        ref.watch(_milestonesProvider(goalId));
    final AsyncValue<List<Project>> projects =
        ref.watch(_projectsProvider(goalId));

    final Goal? goal = chain.value?.goal;

    return Scaffold(
      appBar: AppBar(title: Text(goal?.title ?? 'Goal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showProjectSheet(context, ref, goalId: goalId),
        icon: const Icon(Icons.add),
        label: const Text('Project'),
      ),
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            ErrorStateView(message: 'Could not load this goal.'),
        data: (EntityChain data) {
          if (data.goal == null) {
            return const EmptyStateView(message: 'Goal not found.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              if (data.goal!.description != null) ...<Widget>[
                Text(data.goal!.description!,
                    style: AppTypography.bodyLarge),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (data.goal!.targetDate != null) ...<Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      size: 16,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Target: ${DateFormat.yMMMM().format(data.goal!.targetDate!)}',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              BreadcrumbChain(chain: data, title: 'CONNECTED TO'),
              const SizedBox(height: AppSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text('MILESTONES', style: _label(context)),
                  TextButton(
                    onPressed: () =>
                        showMilestoneSheet(context, ref, goalId: goalId),
                    child: const Text('Add'),
                  ),
                ],
              ),
              milestones.when(
                loading: () => const LoadingShimmer(height: 72),
                error: (Object e, _) => ErrorStateView(
                  message: 'Could not load milestones.',
                ),
                data: (List<Milestone> items) {
                  if (items.isEmpty) {
                    return const AppCard(
                      child: Text('No milestones yet.'),
                    );
                  }
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (final Milestone milestone in items)
                          CheckboxListTile(
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            value:
                                milestone.status == MilestoneStatus.done,
                            title: Text(milestone.title),
                            onChanged: (bool? checked) {
                              ref
                                  .read(goalRepositoryProvider)
                                  .updateMilestone(
                                    milestone.copyWith(
                                      status: (checked ?? false)
                                          ? MilestoneStatus.done
                                          : MilestoneStatus.pending,
                                      updatedAt: DateTime.now().toUtc(),
                                    ),
                                  );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('PROJECTS', style: _label(context)),
              const SizedBox(height: AppSpacing.sm),
              projects.when(
                loading: () => const LoadingShimmer(height: 72),
                error: (Object e, _) =>
                    ErrorStateView(message: 'Could not load projects.'),
                data: (List<Project> items) {
                  if (items.isEmpty) {
                    return EmptyStateView(
                      message: 'No projects driving this goal yet.',
                      icon: Icons.folder_outlined,
                      ctaLabel: 'Create a project',
                      onCta: () =>
                          showProjectSheet(context, ref, goalId: goalId),
                    );
                  }
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (final Project project in items)
                          AppListRow(
                            title: project.title,
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context
                                .go('/future/project/${project.id}'),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static TextStyle _label(BuildContext context) =>
      AppTypography.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      );
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
