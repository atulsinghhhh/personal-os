import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../widgets/daily_review_view.dart';
import '../widgets/monthly_review_view.dart';
import '../widgets/weekly_review_view.dart';

/// The Review tab: Day / Week / Month reviews behind a segmented switcher.
/// Settings hangs off this tab's AppBar (there is no dedicated More tab).
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/review/settings'),
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
