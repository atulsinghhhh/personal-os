import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../savings_goals/domain/entities/savings_goal.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoal>> goals =
        ref.watch(moneySavingsGoalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Savings goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateSheet(context, ref),
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
            ErrorStateView(message: 'Could not load savings goals.'),
        data: (List<SavingsGoal> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message: 'No savings goals yet — set a target to save toward.',
              icon: Icons.savings_outlined,
              ctaLabel: 'Create a savings goal',
              onCta: () => _showCreateSheet(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) =>
                _SavingsGoalCard(goal: all[index]),
          );
        },
      ),
    );
  }

  Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController name = TextEditingController();
    final TextEditingController target = TextEditingController();
    DateTime? targetDate;
    final String currency =
        ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

    return showAppBottomSheet<void>(
      context: context,
      title: 'New savings goal',
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
                  hint: 'e.g. Emergency fund',
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
                    if (value.isEmpty ||
                        amount == null ||
                        amount <= 0 ||
                        userId == null) {
                      return;
                    }
                    final DateTime now = DateTime.now().toUtc();
                    await ref.read(savingsGoalRepositoryProvider).create(
                          SavingsGoal(
                            id: const Uuid().v4(),
                            userId: userId,
                            name: value,
                            targetAmount:
                                Money(amount: amount, currency: currency),
                            currentAmount:
                                Money(amount: 0, currency: currency),
                            targetDate: targetDate,
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

class _SavingsGoalCard extends ConsumerWidget {
  const _SavingsGoalCard({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double target = goal.targetAmount.amount;
    final double current = goal.currentAmount.amount;
    final double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0;

    return AppCard(
      onTap: () => _showEditCurrentSheet(context, ref),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Expanded(
                child: Text(
                  goal.name,
                  style: AppTypography.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.edit_outlined, size: 18),
            ],
          ),
          if (goal.targetDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Target ${DateFormat.yMMMd().format(goal.targetDate!.toLocal())}',
              style: AppTypography.labelSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
            backgroundColor:
                Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatMoney(goal.currentAmount)} of '
            '${formatMoney(goal.targetAmount)}',
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditCurrentSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController amount = TextEditingController(
      text: goal.currentAmount.amount.toStringAsFixed(2),
    );

    return showAppBottomSheet<void>(
      context: context,
      title: 'Update saved amount',
      builder: (BuildContext sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CurrencyInput(
              currencyCode: goal.currentAmount.currency,
              controller: amount,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Save',
              expand: true,
              onPressed: () async {
                final double? value = double.tryParse(amount.text);
                if (value == null || value < 0) return;
                await ref.read(savingsGoalRepositoryProvider).update(
                      goal.copyWith(
                        currentAmount:
                            goal.currentAmount.copyWith(amount: value),
                        updatedAt: DateTime.now().toUtc(),
                      ),
                    );
                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
