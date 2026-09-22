import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
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
      appBar: AppBar(title: Text(budget.value?.name ?? 'Budget')),
      floatingActionButton: budget.value == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddItemSheet(
                context,
                ref,
                budget.value!,
                categories,
              ),
              icon: const Icon(Icons.add),
              label: const Text('Category'),
            ),
      body: budget.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load this budget.'),
        data: (Budget? data) {
          if (data == null) {
            return const EmptyStateView(message: 'Budget not found.');
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: <Widget>[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(data.name, style: AppTypography.titleLarge),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'From ${DateFormat.yMMMd().format(data.periodStart.toLocal())}'
                      ' · ${data.currency}',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('PLANNED VS SPENT', style: moneySectionLabel(context)),
              const SizedBox(height: AppSpacing.sm),
              items.when(
                loading: () => const LoadingShimmer(height: 120),
                error: (Object error, _) =>
                    ErrorStateView(message: 'Could not load budget items.'),
                data: (List<BudgetItem> all) {
                  if (all.isEmpty) {
                    return EmptyStateView(
                      message: 'No categories budgeted yet.',
                      icon: Icons.category_outlined,
                      ctaLabel: 'Add a category',
                      onCta: () => _showAddItemSheet(
                        context,
                        ref,
                        data,
                        categories,
                      ),
                    );
                  }
                  return Column(
                    children: <Widget>[
                      for (int i = 0; i < all.length; i++) ...<Widget>[
                        if (i > 0) const SizedBox(height: AppSpacing.md),
                        _BudgetItemCard(
                          item: all[i],
                          budget: data,
                          categories: categories,
                        ),
                      ],
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

  /// Add-item sheet: expense category picker + planned amount.
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

    return showAppBottomSheet<void>(
      context: context,
      title: 'Budget a category',
      builder: (BuildContext sheetContext) {
        if (expenseCategories.isEmpty) {
          return const Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg),
            child: Text(
              'No expense categories yet — add an expense first to seed the '
              'default category set.',
            ),
          );
        }
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<TransactionCategory>(
                  initialValue: selected,
                  items: <DropdownMenuItem<TransactionCategory>>[
                    for (final TransactionCategory category
                        in expenseCategories)
                      DropdownMenuItem<TransactionCategory>(
                        value: category,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (TransactionCategory? value) =>
                      setState(() => selected = value),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Planned amount (${budget.currency})',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                CurrencyInput(
                  currencyCode: budget.currency,
                  controller: amount,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Add to budget',
                  expand: true,
                  onPressed: () async {
                    final double? planned = double.tryParse(amount.text);
                    final String? userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
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
                            plannedAmount: Money(
                              amount: planned,
                              currency: budget.currency,
                            ),
                            createdAt: now,
                            updatedAt: now,
                          ),
                        );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _BudgetItemCard extends ConsumerWidget {
  const _BudgetItemCard({
    required this.item,
    required this.budget,
    required this.categories,
  });

  final BudgetItem item;
  final Budget budget;
  final List<TransactionCategory> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> spent =
        ref.watch(moneyBudgetItemSpentProvider((item, budget)));

    final double planned = item.plannedAmount.amount;
    final double actual = spent.value?.amount ?? 0;
    final bool over = actual > planned;
    final double progress =
        planned > 0 ? (actual / planned).clamp(0.0, 1.0) : 0;
    final Color barColor = over
        ? context.semanticColors.warning
        : Theme.of(context).colorScheme.primary;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  _categoryName(),
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (over)
                Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: context.semanticColors.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: spent.value == null ? null : progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            color: barColor,
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            spent.value == null
                ? 'Planned ${formatMoney(item.plannedAmount)}'
                : '${formatMoney(spent.value!)} spent of '
                    '${formatMoney(item.plannedAmount)} planned',
            style: AppTypography.bodyMedium.copyWith(
              color: over
                  ? context.semanticColors.warning
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _categoryName() {
    for (final TransactionCategory category in categories) {
      if (category.id == item.categoryId) return category.name;
    }
    return 'Category';
  }
}
