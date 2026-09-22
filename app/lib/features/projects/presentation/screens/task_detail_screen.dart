import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/date_selector.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../../../shared/widgets/breadcrumb_chain.dart';
import '../../domain/entities/project_entities.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForTaskProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Task')),
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            ErrorStateView(message: 'Could not load this task.'),
        data: (EntityChain data) {
          final Task? task = data.task;
          if (task == null) {
            return const EmptyStateView(message: 'Task not found.');
          }
          final bool done = task.status == TaskStatus.done;

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Checkbox(
                    value: done,
                    onChanged: (bool? checked) {
                      ref.read(taskRepositoryProvider).update(
                            task.copyWith(
                              status: (checked ?? false)
                                  ? TaskStatus.done
                                  : TaskStatus.todo,
                              updatedAt: DateTime.now().toUtc(),
                            ),
                          );
                      ref.invalidate(chainForTaskProvider(taskId));
                    },
                  ),
                  Expanded(
                    child: Text(
                      task.title,
                      style: AppTypography.headlineSmall.copyWith(
                        decoration:
                            done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                ],
              ),
              if (task.notes != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(task.notes!, style: AppTypography.bodyMedium),
              ],
              const SizedBox(height: AppSpacing.xl),
              BreadcrumbChain(chain: data),
              const SizedBox(height: AppSpacing.md),
              _BlockedBySection(taskId: taskId),
              const SizedBox(height: AppSpacing.md),
              DateSelector(
                label: 'Scheduled',
                value: task.scheduledDate,
                onChanged: (DateTime date) {
                  ref.read(taskRepositoryProvider).update(
                        task.copyWith(
                          scheduledDate:
                              DateTime.utc(date.year, date.month, date.day),
                          updatedAt: DateTime.now().toUtc(),
                        ),
                      );
                  ref.invalidate(chainForTaskProvider(taskId));
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DateSelector(
                label: 'Due',
                value: task.dueDate,
                onChanged: (DateTime date) {
                  ref.read(taskRepositoryProvider).update(
                        task.copyWith(
                          dueDate:
                              DateTime.utc(date.year, date.month, date.day),
                          updatedAt: DateTime.now().toUtc(),
                        ),
                      );
                  ref.invalidate(chainForTaskProvider(taskId));
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: 'Start focus session',
                icon: Icons.timer_outlined,
                expand: true,
                onPressed: () => context.go('/future/task/$taskId/focus'),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Shows which still-open tasks this one depends on ("Blocked by") with the
/// ability to add/remove dependencies from the same project.
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

        final ColorScheme scheme = Theme.of(context).colorScheme;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.block, size: 16, color: scheme.error),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'BLOCKED BY',
                    style: AppTypography.labelSmall.copyWith(
                      color: scheme.error,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              for (final Task blocker in open)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    blocker.title,
                    style: AppTypography.bodyMedium,
                  ),
                ),
            ],
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
