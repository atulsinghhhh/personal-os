import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../widgets/day_planner_view.dart';
import '../widgets/month_planner_view.dart';
import '../widgets/week_planner_view.dart';
import '../widgets/year_planner_view.dart';

/// The Plan tab: Day / Week / Month / Year planners behind a segmented
/// switcher. Each sub-view keeps its own selected period; an IndexedStack
/// preserves that state when switching segments.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan'),
        actions: <Widget>[
          IconButton(
            tooltip: 'AI planning',
            icon: const Icon(Icons.auto_awesome_outlined),
            onPressed: () => context.go('/plan/ai'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: SegmentedButton<int>(
                segments: const <ButtonSegment<int>>[
                  ButtonSegment<int>(value: 0, label: Text('Day')),
                  ButtonSegment<int>(value: 1, label: Text('Week')),
                  ButtonSegment<int>(value: 2, label: Text('Month')),
                  ButtonSegment<int>(value: 3, label: Text('Year')),
                ],
                selected: <int>{_index},
                showSelectedIcon: false,
                onSelectionChanged: (Set<int> selection) =>
                    setState(() => _index = selection.first),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const <Widget>[
                  DayPlannerView(),
                  WeekPlannerView(),
                  MonthPlannerView(),
                  YearPlannerView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
