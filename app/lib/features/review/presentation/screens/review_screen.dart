import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../widgets/daily_review_view.dart';
import '../widgets/monthly_review_view.dart';
import '../widgets/weekly_review_view.dart';

/// The Review tab: Day / Week / Month reviews behind the sunken segmented
/// switcher. Search, trajectory and settings hang off this tab (there is no
/// dedicated More tab).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _index = 0;

  static const List<String> _segments = <String>['Day', 'Week', 'Month'];

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
              padding: const EdgeInsets.fromLTRB(20, 8, 10, 0),
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
                  _HeaderIcon(
                    icon: LumaIcons.search,
                    label: 'Search',
                    onTap: () => context.push('/review/search'),
                  ),
                  _HeaderIcon(
                    icon: LumaIcons.tabFuture,
                    label: 'Trajectory',
                    onTap: () => context.push('/review/trajectory'),
                  ),
                  _HeaderIcon(
                    icon: LumaIcons.ellipsis,
                    label: 'Settings',
                    onTap: () => context.push('/review/settings'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _index,
                children: const <Widget>[
                  DailyReviewView(),
                  WeeklyReviewView(),
                  MonthlyReviewView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon(
      {required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 44,
          child: Center(
            child: LumaIcon(icon, size: 20, color: LumaColors.ink2),
          ),
        ),
      ),
    );
  }
}
