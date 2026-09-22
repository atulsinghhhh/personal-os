import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../domain/entities/future_entities.dart';
import '../widgets/edit_sheets.dart';

/// Design 16 "Future": vision in italic serif, the horizon line, life areas
/// and goals with serif titles. The conceptual center of the app.
class FutureOverviewScreen extends ConsumerWidget {
  const FutureOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<LifeArea>> lifeAreas =
        ref.watch(lifeAreasStreamProvider);
    final List<Goal> goals =
        ref.watch(goalsStreamProvider).value ?? const <Goal>[];
    final Vision? vision = ref.watch(_firstVisionProvider).value;

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: lifeAreas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => const Center(
            child: ErrorStateView(message: 'Could not load your life areas.')),
        data: (List<LifeArea> areas) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text('PRIVATE · ONLY YOU', style: lumaEyebrow()),
                const LumaIcon(LumaIcons.lock,
                    size: 16, color: LumaColors.ink3),
              ],
            ),
            const SizedBox(height: 28),
            Text('My future', style: lumaSerif(size: 44, height: 1.05)),
            const SizedBox(height: 28),
            const LumaEyebrow('Vision'),
            const SizedBox(height: 12),
            if (vision != null) ...<Widget>[
              Text(
                vision.title,
                style: lumaSerif(size: 25, height: 1.3, style: FontStyle.italic),
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: lumaSans(size: 12.5, color: LumaColors.ink3),
                  children: <InlineSpan>[
                    TextSpan(
                        text:
                            'Written ${DateFormat('MMMM yyyy').format(vision.createdAt.toLocal())} · '),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => showVisionSheet(context, ref),
                        child: Text('Revisit',
                            style: lumaSans(
                                size: 12.5, color: LumaColors.accent)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else
              GestureDetector(
                onTap: () => showVisionSheet(context, ref),
                child: Text(
                  'Write a sentence or two about the life you want. Tap to begin.',
                  style: lumaSerif(
                          size: 25, height: 1.3, style: FontStyle.italic)
                      .copyWith(color: LumaColors.ink3),
                ),
              ),
            const SizedBox(height: 28),
            if (goals.any((Goal g) => g.targetDate != null)) ...<Widget>[
              const LumaEyebrow('Horizon'),
              const SizedBox(height: 16),
              _HorizonLine(goals: goals),
              const SizedBox(height: 28),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const LumaEyebrow('Life areas'),
                GestureDetector(
                  onTap: () => showLifeAreaSheet(context, ref),
                  child: Text('Add area',
                      style: lumaSans(
                          size: 13,
                          weight: FontWeight.w500,
                          color: LumaColors.accent)),
                ),
              ],
            ),
            if (areas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text(
                    'Define the areas of life you want to design on purpose.',
                    style: lumaSans(size: 13, color: LumaColors.ink3)),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 20,
                  mainAxisExtent: 78,
                ),
                itemCount: areas.length,
                itemBuilder: (BuildContext context, int index) {
                  final LifeArea area = areas[index];
                  final int goalCount = goals
                      .where((Goal g) => g.lifeAreaId == area.id)
                      .length;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.go('/future/life-area/${area.id}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: LumaColors.hairline)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(area.name,
                              style: lumaSans(
                                  size: 15, weight: FontWeight.w500)),
                          const SizedBox(height: 6),
                          Text(
                              '$goalCount goal${goalCount == 1 ? '' : 's'}',
                              style: lumaSans(
                                  size: 12, color: LumaColors.ink3)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                const LumaEyebrow('Goals'),
                GestureDetector(
                  onTap: () => showGoalSheet(context, ref),
                  child: Text('New goal',
                      style: lumaSans(
                          size: 13,
                          weight: FontWeight.w500,
                          color: LumaColors.accent)),
                ),
              ],
            ),
            if (goals.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Text('No goals yet — start with one.',
                    style: lumaSans(size: 13, color: LumaColors.ink3)),
              )
            else
              for (final Goal goal in goals)
                _GoalRow(goal: goal, areas: areas),
          ],
        ),
      ),
    );
  }
}

/// One goal row: serif title, metric-driven progress line, meta line.
class _GoalRow extends ConsumerWidget {
  const _GoalRow({required this.goal, required this.areas});

  final Goal goal;
  final List<LifeArea> areas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<GoalMetric> metrics =
        ref.watch(_goalMetricsProvider(goal.id)).value ?? const <GoalMetric>[];
    double? progress;
    for (final GoalMetric metric in metrics) {
      if (metric.targetValue != null && metric.targetValue! > 0) {
        progress = (metric.currentValue / metric.targetValue!).clamp(0.0, 1.0);
        break;
      }
    }
    final String areaName = areas
            .where((LifeArea a) => a.id == goal.lifeAreaId)
            .map((LifeArea a) => a.name)
            .firstOrNull ??
        'Unsorted';
    final String when = goal.targetDate == null
        ? 'ongoing'
        : DateFormat('MMM yyyy').format(goal.targetDate!.toLocal());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/future/goal/${goal.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LumaColors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                Expanded(child: Text(goal.title, style: lumaSerif(size: 23))),
                if (progress != null)
                  Text('${(progress * 100).round()}%',
                      style: lumaSans(size: 13, color: LumaColors.ink2)),
              ],
            ),
            if (progress != null) ...<Widget>[
              const SizedBox(height: 8),
              LumaProgressLine(value: progress, height: 3),
            ],
            const SizedBox(height: 8),
            Text('$areaName · $when',
                style: lumaSans(size: 12.5, color: LumaColors.ink3)),
          ],
        ),
      ),
    );
  }
}

/// Up to four dated goals placed along a hairline horizon (design 16).
class _HorizonLine extends StatelessWidget {
  const _HorizonLine({required this.goals});

  final List<Goal> goals;

  @override
  Widget build(BuildContext context) {
    final List<Goal> dated = goals
        .where((Goal g) => g.targetDate != null)
        .toList(growable: false)
      ..sort((Goal a, Goal b) => a.targetDate!.compareTo(b.targetDate!));
    final List<Goal> shown = dated.take(4).toList(growable: false);
    if (shown.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 70,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;
          return Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: 4,
                child: Container(height: 1, color: LumaColors.hairline),
              ),
              for (int i = 0; i < shown.length; i++)
                Positioned(
                  left: (0.08 + (shown.length == 1 ? 0 : 0.74 * i / (shown.length - 1))) *
                          width -
                      5,
                  top: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0
                              ? LumaColors.accent
                              : LumaColors.ground,
                          border: Border.all(
                              color: LumaColors.accent, width: 1.5),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('${shown[i].targetDate!.year}',
                          style:
                              lumaSans(size: 11, color: LumaColors.ink3)),
                      const SizedBox(height: 6),
                      Text(
                        shown[i].title.length > 18
                            ? '${shown[i].title.substring(0, 17)}…'
                            : shown[i].title,
                        style:
                            lumaSans(size: 12, weight: FontWeight.w500),
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
}

final StreamProvider<List<LifeArea>> lifeAreasStreamProvider =
    StreamProvider<List<LifeArea>>((Ref ref) {
  return ref.watch(lifeAreaRepositoryProvider).watchAll();
});

final StreamProvider<List<Goal>> goalsStreamProvider =
    StreamProvider<List<Goal>>((Ref ref) {
  return ref.watch(goalRepositoryProvider).watchAll();
});

final StreamProvider<Vision?> _firstVisionProvider =
    StreamProvider<Vision?>((Ref ref) {
  return ref
      .watch(visionRepositoryProvider)
      .watchAll()
      .map((List<Vision> visions) => visions.isEmpty ? null : visions.first);
});

final _goalMetricsProvider =
    StreamProvider.family<List<GoalMetric>, String>((Ref ref, String goalId) {
  return ref.watch(goalRepositoryProvider).watchMetrics(goalId);
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
