import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'luma_icons.dart';

/// Bottom navigation: 84px tall on ground, hairline top border, five tabs
/// (Today, Plan, Future, Money, Review) with the design's stroke icons.
class LumaTabBar extends StatelessWidget {
  const LumaTabBar({
    super.key,
    required this.currentIndex,
    required this.onSelect,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const List<String> labels = [
    'Today',
    'Plan',
    'Future',
    'Money',
    'Review',
  ];

  static const List<String> icons = [
    LumaIcons.tabToday,
    LumaIcons.tabPlan,
    LumaIcons.tabFuture,
    LumaIcons.tabMoney,
    LumaIcons.tabReview,
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 84 + bottomInset,
      padding: EdgeInsets.only(left: 8, right: 8, bottom: bottomInset),
      decoration: const BoxDecoration(
        color: LumaColors.ground,
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                label: labels[i],
                button: true,
                selected: i == currentIndex,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onSelect(i),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      children: [
                        LumaIcon(icons[i],
                            size: 22,
                            color: i == currentIndex
                                ? LumaColors.ink
                                : LumaColors.ink3),
                        const SizedBox(height: 4),
                        Text(
                          labels[i],
                          style: lumaSans(
                            size: 10.5,
                            weight: i == currentIndex
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: i == currentIndex
                                ? LumaColors.ink
                                : LumaColors.ink3,
                            letterSpacing: 10.5 * 0.02,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 56px round black quick-capture FAB, sits above the tab bar.
class LumaFab extends StatelessWidget {
  const LumaFab({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Quick capture',
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 56,
          height: 56,
          decoration: const BoxDecoration(
            color: LumaColors.ink,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x2E1B1B19),
                offset: Offset(0, 6),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Center(
            child: LumaIcon(LumaIcons.plus,
                size: 24, color: LumaColors.surface, strokeWidth: 1.8),
          ),
        ),
      ),
    );
  }
}
