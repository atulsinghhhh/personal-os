import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../domain/entities/future_entities.dart';
import '../widgets/edit_sheets.dart';

/// The conceptual center: life areas with their visions and goals. Tapping
/// a life area drills into it; goals navigate to goal detail.
class FutureOverviewScreen extends ConsumerWidget {
  const FutureOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LifeArea>> lifeAreas =
        ref.watch(lifeAreasStreamProvider);
    final AsyncValue<List<Goal>> goals = ref.watch(goalsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Future'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Add life area',
            icon: const Icon(Icons.add),
            onPressed: () => showLifeAreaSheet(context, ref),
          ),
        ],
      ),
      body: lifeAreas.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              LoadingShimmer(height: 80),
              SizedBox(height: AppSpacing.md),
              LoadingShimmer(height: 80),
            ],
          ),
        ),
        error: (Object error, _) => ErrorStateView(
          message: 'Could not load your life areas.',
        ),
        data: (List<LifeArea> areas) {
          if (areas.isEmpty) {
            return EmptyStateView(
              message:
                  'Define the areas of life you want to design on purpose.',
              icon: Icons.auto_awesome_outlined,
              ctaLabel: 'Add a life area',
              onCta: () => showLifeAreaSheet(context, ref),
            );
          }
          final List<Goal> allGoals = goals.value ?? <Goal>[];
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: areas.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final LifeArea area = areas[index];
              final int goalCount = allGoals
                  .where((Goal g) => g.lifeAreaId == area.id)
                  .length;
              return AppCard(
                onTap: () => context.go('/future/life-area/${area.id}'),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 40,
                      decoration: BoxDecoration(
                        color: parseHexColor(area.color) ??
                            Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(area.name, style: AppTypography.titleMedium),
                          Text(
                            '$goalCount goal${goalCount == 1 ? '' : 's'}',
                            style: AppTypography.labelSmall.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

final StreamProvider<List<LifeArea>> lifeAreasStreamProvider =
    StreamProvider<List<LifeArea>>((Ref ref) {
  return ref.watch(lifeAreaRepositoryProvider).watchAll();
});

final StreamProvider<List<Goal>> goalsStreamProvider =
    StreamProvider<List<Goal>>((Ref ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});

Color? parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  final String cleaned = hex.replaceFirst('#', '');
  final int? value = int.tryParse(
    cleaned.length == 6 ? 'FF$cleaned' : cleaned,
    radix: 16,
  );
  return value == null ? null : Color(value);
}
