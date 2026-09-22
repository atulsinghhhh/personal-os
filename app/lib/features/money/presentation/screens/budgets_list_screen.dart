import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../budgets/domain/entities/budget_entities.dart';
import '../providers/money_providers.dart';

/// Design "Budget": one row per budget with a hairline progress line showing
/// pace against the planned total.
class BudgetsListScreen extends ConsumerWidget {
  const BudgetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Budget>> budgets = ref.watch(moneyBudgetsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Budgets', style: lumaSerif(size: 40, height: 1.05)),
              GestureDetector(
                onTap: () => showCreateBudgetSheet(context, ref),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          budgets.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load budgets.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<Budget> all) {
              if (all.isEmpty) {
                return GestureDetector(
                  onTap: () => showCreateBudgetSheet(context, ref),
                  child: Text(
                      'No budgets yet — plan your spending by category.',
                      style: lumaSans(
                          size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                );
              }
              return Column(
                children: <Widget>[
                  for (final Budget budget in all) _BudgetRow(budget: budget),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BudgetRow extends ConsumerWidget {
  const _BudgetRow({required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<BudgetPace> pace = ref.watch(moneyBudgetPaceProvider(budget.id));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/money/budgets/${budget.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LumaColors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(
                    child: Text(budget.name,
                        style: lumaSans(size: 16, weight: FontWeight.w500))),
                const LumaIcon(LumaIcons.chevronRight, size: 18, color: LumaColors.ink3),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_periodLabel(budget.period)} · from '
              '${DateFormat.yMMMd().format(budget.periodStart.toLocal())} · ${budget.currency}',
              style: lumaSans(size: 12.5, color: LumaColors.ink3),
            ),
            const SizedBox(height: 10),
            pace.when(
              loading: () => const LumaProgressLine(value: 0, height: 5),
              error: (Object error, _) => const SizedBox.shrink(),
              data: (BudgetPace p) {
                final double fraction = p.planned <= 0
                    ? 0
                    : (p.actual / p.planned).clamp(0.0, 1.0);
                return LumaProgressLine(
                  value: fraction,
                  height: 5,
                  color: p.actual > p.planned ? LumaColors.warning : LumaColors.accent,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _periodLabel(BudgetPeriod period) => switch (period) {
      BudgetPeriod.weekly => 'Weekly',
      BudgetPeriod.monthly => 'Monthly',
      BudgetPeriod.custom => 'Custom',
    };

/// Create-budget sheet: name + period (monthly default). Period start is the
/// first of the current month; currency comes from the profile default.
Future<void> showCreateBudgetSheet(BuildContext context, WidgetRef ref) {
  final TextEditingController name = TextEditingController();
  BudgetPeriod period = BudgetPeriod.monthly;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: LumaColors.ground,
    barrierColor: const Color(0x521B1B19),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 38,
                      height: 5,
                      decoration: BoxDecoration(
                        color: LumaColors.hairline,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const LumaEyebrow('New budget'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    autofocus: true,
                    style: lumaSerif(size: 26, height: 1.15),
                    cursorColor: LumaColors.ink,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: 'e.g. Monthly essentials',
                      hintStyle:
                          lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: <Widget>[
                      for (final BudgetPeriod value in BudgetPeriod.values) ...<Widget>[
                        if (value != BudgetPeriod.values.first) const SizedBox(width: 8),
                        LumaChip(
                          label: _periodLabel(value),
                          selected: period == value,
                          onTap: () => setState(() => period = value),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 24),
                  LumaPrimaryButton(
                    label: 'Create budget',
                    height: 52,
                    onTap: () async {
                      final String value = name.text.trim();
                      final String? userId =
                          ref.read(supabaseClientProvider).auth.currentUser?.id;
                      if (value.isEmpty || userId == null) return;
                      final String currency = ref
                              .read(currentProfileProvider)
                              .value
                              ?.defaultCurrency ??
                          'USD';
                      final DateTime now = DateTime.now().toUtc();
                      final DateTime periodStart = DateTime.utc(now.year, now.month, 1);
                      await ref.read(budgetRepositoryProvider).create(
                            Budget(
                              id: const Uuid().v4(),
                              userId: userId,
                              name: value,
                              period: period,
                              periodStart: periodStart,
                              currency: currency,
                              createdAt: now,
                              updatedAt: now,
                            ),
                          );
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
