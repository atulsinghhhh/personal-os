import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../domain/entities/future_entities.dart';
import '../widgets/edit_sheets.dart';

class LifeAreaScreen extends ConsumerWidget {
  const LifeAreaScreen({super.key, required this.lifeAreaId});

  final String lifeAreaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LifeArea?> area =
        ref.watch(_lifeAreaProvider(lifeAreaId));
    final AsyncValue<List<Vision>> visions =
        ref.watch(_visionsProvider(lifeAreaId));
    final AsyncValue<List<Goal>> goals =
        ref.watch(_goalsProvider(lifeAreaId));

    return Scaffold(
      appBar: AppBar(title: Text(area.value?.name ?? 'Life area')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showGoalSheet(context, ref, lifeAreaId: lifeAreaId),
        icon: const Icon(Icons.add),
        label: const Text('Goal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('VISION', style: _label(context)),
              TextButton(
                onPressed: () =>
                    showVisionSheet(context, ref, lifeAreaId: lifeAreaId),
                child: const Text('Add'),
              ),
            ],
          ),
          visions.when(
            loading: () => const LoadingShimmer(height: 72),
            error: (Object e, _) =>
                ErrorStateView(message: 'Could not load visions.'),
            data: (List<Vision> items) {
              if (items.isEmpty) {
                return AppCard(
                  child: Text(
                    'No vision for this area yet.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Vision vision in items)
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(child: Text(vision.title)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('GOALS', style: _label(context)),
          const SizedBox(height: AppSpacing.sm),
          goals.when(
            loading: () => const LoadingShimmer(height: 120),
            error: (Object e, _) =>
                ErrorStateView(message: 'Could not load goals.'),
            data: (List<Goal> items) {
              if (items.isEmpty) {
                return EmptyStateView(
                  message: 'No goals in this area yet.',
                  icon: Icons.track_changes,
                  ctaLabel: 'Create a goal',
                  onCta: () =>
                      showGoalSheet(context, ref, lifeAreaId: lifeAreaId),
                );
              }
              return AppCard(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Column(
                  children: <Widget>[
                    for (final Goal goal in items)
                      AppListRow(
                        title: goal.title,
                        subtitle: goal.targetDate == null
                            ? null
                            : 'Target: ${goal.targetDate!.year}-${goal.targetDate!.month.toString().padLeft(2, '0')}',
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/future/goal/${goal.id}'),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  static TextStyle _label(BuildContext context) =>
      AppTypography.labelMedium.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      );
}

final _lifeAreaProvider = FutureProvider.family<LifeArea?, String>((
  Ref ref,
  String id,
) {
  return ref.read(lifeAreaRepositoryProvider).getById(id);
});

final _visionsProvider = StreamProvider.family<List<Vision>, String>((
  Ref ref,
  String id,
) {
  return ref.watch(visionRepositoryProvider).watchByLifeArea(id);
});

final _goalsProvider = StreamProvider.family<List<Goal>, String>((
  Ref ref,
  String id,
) {
  return ref.watch(goalRepositoryProvider).watchByLifeArea(id);
});
