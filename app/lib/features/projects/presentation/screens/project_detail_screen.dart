import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/providers/chain_providers.dart';
import '../../../../shared/widgets/breadcrumb_chain.dart';
import '../../../future/presentation/widgets/edit_sheets.dart';
import '../../domain/entities/project_entities.dart';

class ProjectDetailScreen extends ConsumerWidget {
  const ProjectDetailScreen({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<EntityChain> chain =
        ref.watch(chainForProjectProvider(projectId));
    final AsyncValue<List<Task>> tasks =
        ref.watch(_tasksProvider(projectId));

    return Scaffold(
      appBar: AppBar(title: Text(chain.value?.project?.title ?? 'Project')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTaskSheet(context, ref, projectId: projectId),
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: chain.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) =>
            ErrorStateView(message: 'Could not load this project.'),
        data: (EntityChain data) {
          if (data.project == null) {
            return const EmptyStateView(message: 'Project not found.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              BreadcrumbChain(chain: data, title: 'WHY THIS PROJECT?'),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'TASKS',
                style: AppTypography.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              tasks.when(
                loading: () => const LoadingShimmer(height: 120),
                error: (Object e, _) =>
                    ErrorStateView(message: 'Could not load tasks.'),
                data: (List<Task> items) {
                  if (items.isEmpty) {
                    return EmptyStateView(
                      message: 'No tasks in this project yet.',
                      icon: Icons.check_circle_outline,
                      ctaLabel: 'Add a task',
                      onCta: () => showTaskSheet(
                        context,
                        ref,
                        projectId: projectId,
                      ),
                    );
                  }
                  return AppCard(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      children: <Widget>[
                        for (final Task task in items)
                          CheckboxListTile(
                            dense: true,
                            controlAffinity:
                                ListTileControlAffinity.leading,
                            value: task.status == TaskStatus.done,
                            title: Text(
                              task.title,
                              style: TextStyle(
                                decoration: task.status == TaskStatus.done
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            secondary: IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () => context
                                  .go('/future/task/${task.id}'),
                            ),
                            onChanged: (bool? checked) {
                              ref.read(taskRepositoryProvider).update(
                                    task.copyWith(
                                      status: (checked ?? false)
                                          ? TaskStatus.done
                                          : TaskStatus.todo,
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
            ],
          );
        },
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
