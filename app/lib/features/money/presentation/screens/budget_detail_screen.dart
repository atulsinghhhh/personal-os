import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/models/money.dart';
import '../../budgets/domain/entities/budget_entities.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.budgetId});

  final String budgetId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Budget?> budget = ref.watch(moneyBudgetProvider(budgetId));
    final AsyncValue<List<BudgetItem>> items =
        ref.watch(moneyBudgetItemsProvider(budgetId));
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: budget.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(
            child: Text('Could not load this budget.',
                style: lumaSans(size: 14, color: LumaColors.ink3))),
        data: (Budget? data) {
          if (data == null) {
            return Center(
                child: Text('Budget not found.',
                    style: lumaSans(size: 14, color: LumaColors.ink3)));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
            children: <Widget>[
              SizedBox(
                height: 44,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.canPop()
                      ? context.pop()
                      : context.go('${RoutePaths.money}/budgets'),
                  child: Row(
                    children: <Widget>[
                      const LumaIcon(LumaIcons.chevronLeft,
                          size: 22, color: LumaColors.ink2),
                      const SizedBox(width: 2),
                      Text('Back', style: lumaSans(size: 15, color: LumaColors.ink2)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(data.name, style: lumaSerif(size: 36, height: 1.05)),
              const SizedBox(height: 8),
              Text(
                'From ${DateFormat.yMMMd().format(data.periodStart.toLocal())} · ${data.currency}',
                style: lumaSans(size: 13, color: LumaColors.ink3),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const LumaEyebrow('Planned vs spent'),
                  GestureDetector(
                    onTap: () => _showAddItemSheet(context, ref, data, categories),
                    child: Text('Add category',
                        style: lumaSans(
                            size: 13, weight: FontWeight.w500, color: LumaColors.accent)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              items.when(
                loading: () => const SizedBox(height: 120),
                error: (Object error, _) => Text('Could not load budget items.',
                    style: lumaSans(size: 14, color: LumaColors.ink3)),
                data: (List<BudgetItem> all) {
                  if (all.isEmpty) {
                    return GestureDetector(
                      onTap: () => _showAddItemSheet(context, ref, data, categories),
                      child: Text('No categories budgeted yet.',
                          style: lumaSans(
                              size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (final BudgetItem item in all)
                        _BudgetItemRow(item: item, budget: data, categories: categories),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showAddItemSheet(
    BuildContext context,
    WidgetRef ref,
    Budget budget,
    List<TransactionCategory> categories,
  ) {
    final List<TransactionCategory> expenseCategories = categories
        .where((TransactionCategory c) => c.kind == CategoryKind.expense)
        .toList(growable: false);
    final TextEditingController amount = TextEditingController();
    TransactionCategory? selected =
        expenseCategories.isEmpty ? null : expenseCategories.first;

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
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                    const LumaEyebrow('Budget a category'),
                    const SizedBox(height: 16),
                    if (expenseCategories.isEmpty)
                      Text(
                        'No expense categories yet — add an expense first to '
                        'seed the default category set.',
                        style: lumaSans(size: 14, color: LumaColors.ink3),
                      )
                    else ...<Widget>[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: <Widget>[
                            for (final TransactionCategory category
                                in expenseCategories) ...<Widget>[
                              if (category != expenseCategories.first)
                                const SizedBox(width: 8),
                              LumaChip(
                                label: category.name,
                                selected: selected?.id == category.id,
                                onTap: () => setState(() => selected = category),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      CurrencyInput(currencyCode: budget.currency, controller: amount),
                      const SizedBox(height: 24),
                      LumaPrimaryButton(
                        label: 'Add to budget',
                        height: 52,
                        onTap: () async {
                          final double? planned = double.tryParse(amount.text);
                          final String? userId =
                              ref.read(supabaseClientProvider).auth.currentUser?.id;
                          final TransactionCategory? category = selected;
                          if (planned == null ||
                              planned <= 0 ||
                              userId == null ||
                              category == null) {
                            return;
                          }
                          final DateTime now = DateTime.now().toUtc();
                          await ref.read(budgetRepositoryProvider).upsertItem(
                                BudgetItem(
                                  id: const Uuid().v4(),
                                  userId: userId,
                                  budgetId: budget.id,
                                  categoryId: category.id,
                                  plannedAmount:
                                      Money(amount: planned, currency: budget.currency),
                                  createdAt: now,
                                  updatedAt: now,
                                ),
                              );
                          if (context.mounted) Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BudgetItemRow extends ConsumerWidget {
  const _BudgetItemRow({
    required this.item,
    required this.budget,
    required this.categories,
  });

  final BudgetItem item;
  final Budget budget;
  final List<TransactionCategory> categories;

  String get _categoryName {
    for (final TransactionCategory category in categories) {
      if (category.id == item.categoryId) return category.name;
    }
    return 'Category';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> spent = ref.watch(moneyBudgetItemSpentProvider((item, budget)));
    final double planned = item.plannedAmount.amount;
    final double actual = spent.value?.amount ?? 0;
    final bool over = actual > planned;
    final double progress = planned > 0 ? (actual / planned).clamp(0.0, 1.0) : 0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
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
                  child: Text(_categoryName,
                      style: lumaSans(size: 15, weight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis)),
              if (over)
                const LumaIcon(LumaIcons.flag, size: 15, color: LumaColors.warning),
            ],
          ),
          const SizedBox(height: 8),
          LumaProgressLine(
            value: spent.value == null ? 0 : progress,
            height: 6,
            color: over ? LumaColors.warning : LumaColors.accent,
          ),
          const SizedBox(height: 8),
          Text(
            spent.value == null
                ? 'Planned ${formatMoney(item.plannedAmount)}'
                : '${formatMoney(spent.value!)} spent of ${formatMoney(item.plannedAmount)} planned',
            style: lumaSans(size: 12.5, color: over ? LumaColors.warning : LumaColors.ink3),
          ),
        ],
      ),
    );
  }
}
