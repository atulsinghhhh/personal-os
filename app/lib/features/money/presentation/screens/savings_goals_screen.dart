import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/models/money.dart';
import '../../savings_goals/domain/entities/savings_goal.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Savings goals: hairline-separated rows, each a progress line toward a
/// target amount. Tap to update the saved-so-far figure.
class SavingsGoalsScreen extends ConsumerWidget {
  const SavingsGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavingsGoal>> goals = ref.watch(moneySavingsGoalsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Savings goals', style: lumaSerif(size: 34, height: 1.05)),
              GestureDetector(
                onTap: () => _showCreateSheet(context, ref),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          goals.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load savings goals.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<SavingsGoal> all) {
              if (all.isEmpty) {
                return GestureDetector(
                  onTap: () => _showCreateSheet(context, ref),
                  child: Text('No savings goals yet — set a target to save toward.',
                      style: lumaSans(
                          size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                );
              }
              return Column(
                children: <Widget>[
                  for (final SavingsGoal goal in all) _SavingsGoalRow(goal: goal),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static Future<void> _showCreateSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController name = TextEditingController();
    final TextEditingController target = TextEditingController();
    DateTime? targetDate;
    final String currency = ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

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
                    const LumaEyebrow('New savings goal'),
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
                        hintText: 'e.g. Emergency fund',
                        hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    CurrencyInput(currencyCode: currency, controller: target, autofocus: false),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final DateTime now = DateTime.now();
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: targetDate ?? now,
                          firstDate: DateTime(now.year - 1),
                          lastDate: DateTime(now.year + 30),
                        );
                        if (picked != null) setState(() => targetDate = picked);
                      },
                      child: Text(
                        targetDate == null
                            ? 'Target date (optional)'
                            : DateFormat.yMMMd().format(targetDate!),
                        style: lumaSans(size: 14, color: LumaColors.ink2),
                      ),
                    ),
                    const SizedBox(height: 24),
                    LumaPrimaryButton(
                      label: 'Create goal',
                      height: 52,
                      onTap: () async {
                        final String value = name.text.trim();
                        final double? amount = double.tryParse(target.text);
                        final String? userId =
                            ref.read(supabaseClientProvider).auth.currentUser?.id;
                        if (value.isEmpty || amount == null || amount <= 0 || userId == null) {
                          return;
                        }
                        final DateTime now = DateTime.now().toUtc();
                        await ref.read(savingsGoalRepositoryProvider).create(
                              SavingsGoal(
                                id: const Uuid().v4(),
                                userId: userId,
                                name: value,
                                targetAmount: Money(amount: amount, currency: currency),
                                currentAmount: Money(amount: 0, currency: currency),
                                targetDate: targetDate,
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
}

class _SavingsGoalRow extends ConsumerWidget {
  const _SavingsGoalRow({required this.goal});

  final SavingsGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double target = goal.targetAmount.amount;
    final double current = goal.currentAmount.amount;
    final double progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showEditCurrentSheet(context, ref),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LumaColors.hairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(goal.name, style: lumaSans(size: 16, weight: FontWeight.w500)),
            if (goal.targetDate != null) ...<Widget>[
              const SizedBox(height: 4),
              Text('Target ${DateFormat.yMMMd().format(goal.targetDate!.toLocal())}',
                  style: lumaSans(size: 12.5, color: LumaColors.ink3)),
            ],
            const SizedBox(height: 10),
            LumaProgressLine(value: progress, height: 6),
            const SizedBox(height: 8),
            Text('${formatMoney(goal.currentAmount)} of ${formatMoney(goal.targetAmount)}',
                style: lumaSans(size: 12.5, color: LumaColors.ink3)),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditCurrentSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController amount =
        TextEditingController(text: goal.currentAmount.amount.toStringAsFixed(2));

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: LumaColors.ground,
      barrierColor: const Color(0x521B1B19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
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
                const LumaEyebrow('Update saved amount'),
                const SizedBox(height: 16),
                CurrencyInput(currencyCode: goal.currentAmount.currency, controller: amount),
                const SizedBox(height: 24),
                LumaPrimaryButton(
                  label: 'Save',
                  height: 52,
                  onTap: () async {
                    final double? value = double.tryParse(amount.text);
                    if (value == null || value < 0) return;
                    await ref.read(savingsGoalRepositoryProvider).update(
                          goal.copyWith(
                            currentAmount: goal.currentAmount.copyWith(amount: value),
                            updatedAt: DateTime.now().toUtc(),
                          ),
                        );
                    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
