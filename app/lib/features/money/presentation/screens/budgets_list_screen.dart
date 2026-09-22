import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../budgets/domain/entities/budget_entities.dart';
import '../providers/money_providers.dart';

class BudgetsListScreen extends ConsumerWidget {
  const BudgetsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Budget>> budgets = ref.watch(moneyBudgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateBudgetSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Budget'),
      ),
      body: budgets.when(
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
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load budgets.'),
        data: (List<Budget> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message: 'No budgets yet — plan your spending by category.',
              icon: Icons.pie_chart_outline,
              ctaLabel: 'Create a budget',
              onCta: () => showCreateBudgetSheet(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final Budget budget = all[index];
              return AppCard(
                onTap: () => context.go('/money/budgets/${budget.id}'),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(budget.name, style: AppTypography.titleMedium),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '${_periodLabel(budget.period)} · from '
                            '${DateFormat.yMMMd().format(budget.periodStart.toLocal())}'
                            ' · ${budget.currency}',
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

  return showAppBottomSheet<void>(
    context: context,
    title: 'New budget',
    builder: (BuildContext sheetContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              AppTextField(
                controller: name,
                label: 'Name',
                hint: 'e.g. Monthly essentials',
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Period', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<BudgetPeriod>(
                segments: <ButtonSegment<BudgetPeriod>>[
                  for (final BudgetPeriod value in BudgetPeriod.values)
                    ButtonSegment<BudgetPeriod>(
                      value: value,
                      label: Text(_periodLabel(value)),
                    ),
                ],
                selected: <BudgetPeriod>{period},
                onSelectionChanged: (Set<BudgetPeriod> selection) =>
                    setState(() => period = selection.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create budget',
                expand: true,
                onPressed: () async {
                  final String value = name.text.trim();
                  final String? userId = ref
                      .read(supabaseClientProvider)
                      .auth
                      .currentUser
                      ?.id;
                  if (value.isEmpty || userId == null) return;
                  final String currency = ref
                          .read(currentProfileProvider)
                          .value
                          ?.defaultCurrency ??
                      'USD';
                  final DateTime now = DateTime.now().toUtc();
                  final DateTime periodStart =
                      DateTime.utc(now.year, now.month, 1);
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
          );
        },
      );
    },
  );
}
