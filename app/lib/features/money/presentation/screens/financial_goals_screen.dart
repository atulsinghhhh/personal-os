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
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/date_selector.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../financial_goals/domain/entities/financial_goal.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Financial goals: money targets, optionally linked to a life Goal. No
/// progress numbers are fabricated — only the recorded target and link show.
class FinancialGoalsScreen extends ConsumerWidget {
  const FinancialGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialGoal>> goals =
        ref.watch(moneyFinancialGoalsProvider);
    final List<Goal> lifeGoals =
        ref.watch(moneyLifeGoalsProvider).value ?? <Goal>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Financial goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref, lifeGoals),
        icon: const Icon(Icons.add),
        label: const Text('Goal'),
      ),
      body: goals.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: <Widget>[
              LoadingShimmer(height: 100),
              SizedBox(height: AppSpacing.md),
              LoadingShimmer(height: 100),
            ],
          ),
        ),
        error: (Object error, _) =>
            ErrorStateView(message: 'Could not load financial goals.'),
        data: (List<FinancialGoal> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message:
                  'No financial goals yet — give your money a direction.',
              icon: Icons.flag_outlined,
              ctaLabel: 'Create a financial goal',
              onCta: () => _showCreateSheet(context, ref, lifeGoals),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final FinancialGoal goal = all[index];
              final Goal? linked = _linkedGoal(goal, lifeGoals);
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(goal.name, style: AppTypography.titleMedium),
                    const SizedBox(height: AppSpacing.xs),
                    if (goal.targetAmount != null)
                      Text(
                        'Target: ${formatMoney(goal.targetAmount!)}',
                        style: AppTypography.currencyMedium,
                      ),
                    if (goal.targetDate != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'By ${DateFormat.yMMMd().format(goal.targetDate!.toLocal())}',
                        style: AppTypography.bodyMedium.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (linked != null) ...<Widget>[
                      const SizedBox(height: AppSpacing.sm),
                      InkWell(
                        onTap: () =>
                            context.go('/future/goal/${linked.id}'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.link,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Flexible(
                              child: Text(
                                linked.title,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMedium.copyWith(
                                  color:
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static Goal? _linkedGoal(FinancialGoal goal, List<Goal> lifeGoals) {
    for (final Goal candidate in lifeGoals) {
      if (candidate.id == goal.linkedGoalId) return candidate;
    }
    return null;
  }

  Future<void> _showCreateSheet(
    BuildContext context,
    WidgetRef ref,
    List<Goal> lifeGoals,
  ) {
    final TextEditingController name = TextEditingController();
    final TextEditingController target = TextEditingController();
    DateTime? targetDate;
    Goal? linkedGoal;
    final String currency =
        ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return showAppBottomSheet<void>(
      context: context,
      title: 'New financial goal',
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
                  hint: 'e.g. Pay off the car loan',
                  autofocus: true,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Target amount ($currency)',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                CurrencyInput(
                  currencyCode: currency,
                  controller: target,
                  autofocus: false,
                ),
                const SizedBox(height: AppSpacing.md),
                DateSelector(
                  label: 'Target date (optional)',
                  value: targetDate,
                  onChanged: (DateTime picked) =>
                      setState(() => targetDate = picked),
                ),
                if (lifeGoals.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Linked life goal (optional)',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  DropdownButtonFormField<Goal?>(
                    initialValue: linkedGoal,
                    items: <DropdownMenuItem<Goal?>>[
                      const DropdownMenuItem<Goal?>(
                        child: Text('None'),
                      ),
                      for (final Goal goal in lifeGoals)
                        DropdownMenuItem<Goal?>(
                          value: goal,
                          child: Text(
                            goal.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (Goal? value) =>
                        setState(() => linkedGoal = value),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                AppButton(
                  label: 'Create goal',
                  expand: true,
                  onPressed: () async {
                    final String value = name.text.trim();
                    final double? amount = double.tryParse(target.text);
                    final String? userId = ref
                        .read(supabaseClientProvider)
                        .auth
                        .currentUser
                        ?.id;
                    if (value.isEmpty || userId == null) return;
                    final DateTime now = DateTime.now().toUtc();
                    await ref.read(financialGoalRepositoryProvider).create(
                          FinancialGoal(
                            id: const Uuid().v4(),
                            userId: userId,
                            name: value,
                            goalType: FinancialGoalType.custom,
                            targetAmount: amount == null || amount <= 0
                                ? null
                                : Money(amount: amount, currency: currency),
                            targetDate: targetDate,
                            linkedGoalId: linkedGoal?.id,
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
