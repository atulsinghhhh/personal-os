import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../widgets/day_planner_view.dart';
import '../widgets/month_planner_view.dart';
import '../widgets/week_planner_view.dart';
import '../widgets/year_planner_view.dart';

/// The Plan tab: Day / Week / Month / Year planners behind the design's
/// sunken segmented switcher. Each sub-view keeps its own selected period;
/// an IndexedStack preserves that state when switching segments.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  int _index = 0;

  static const List<String> _segments = <String>[
    'Day',
    'Week',
    'Month',
    'Year',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: LumaColors.sunken,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: <Widget>[
                          for (int i = 0; i < _segments.length; i++)
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _index = i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 8),
                                  decoration: i == _index
                                      ? BoxDecoration(
                                          color: LumaColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(9),
                                          boxShadow: const <BoxShadow>[
                                            BoxShadow(
                                              color: Color(0x141B1B19),
                                              offset: Offset(0, 1),
                                              blurRadius: 2,
                                            ),
                                          ],
                                        )
                                      : null,
                                  child: Text(
                                    _segments[i],
                                    textAlign: TextAlign.center,
                                    style: lumaSans(
                                      size: 13,
                                      weight: i == _index
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: i == _index
                                          ? LumaColors.ink
                                          : LumaColors.ink2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Semantics(
                    label: 'AI planning',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.go('/plan/ai'),
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: LumaIcon(LumaIcons.sparkle,
                              size: 20, color: LumaColors.ink2),
                        ),
                      ),
                    ),
                  ),
                ],
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
