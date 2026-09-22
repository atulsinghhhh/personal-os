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
import '../../../../shared/models/money.dart';
import '../../../goals/domain/entities/goal_entities.dart';
import '../../financial_goals/domain/entities/financial_goal.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Design "FinancialGoal": one hairline-separated row per goal — serif
/// title, target amount, target date, and an optional link to the life goal
/// it serves. Nothing here is fabricated: only the recorded target shows.
class FinancialGoalsScreen extends ConsumerWidget {
  const FinancialGoalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialGoal>> goals = ref.watch(moneyFinancialGoalsProvider);
    final List<Goal> lifeGoals = ref.watch(moneyLifeGoalsProvider).value ?? <Goal>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Financial goals', style: lumaSerif(size: 34, height: 1.05)),
              GestureDetector(
                onTap: () => _showCreateSheet(context, ref, lifeGoals),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          goals.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load financial goals.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<FinancialGoal> all) {
              if (all.isEmpty) {
                return GestureDetector(
                  onTap: () => _showCreateSheet(context, ref, lifeGoals),
                  child: Text('No financial goals yet — give your money a direction.',
                      style: lumaSans(
                          size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                );
              }
              return Column(
                children: <Widget>[
                  for (final FinancialGoal goal in all)
                    _FinancialGoalRow(goal: goal, linked: _linkedGoal(goal, lifeGoals)),
                ],
              );
            },
          ),
        ],
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
                    const LumaEyebrow('New financial goal'),
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
                        hintText: 'e.g. Pay off the car loan',
                        hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: target,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: lumaSans(size: 17, weight: FontWeight.w500),
                      cursorColor: LumaColors.ink,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        hintText: 'Target amount ($currency)',
                        hintStyle: lumaSans(size: 17, color: LumaColors.ink3),
                      ),
                    ),
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
                      child: Row(
                        children: <Widget>[
                          const LumaIcon(LumaIcons.chevronRight,
                              size: 16, color: LumaColors.ink3),
                          const SizedBox(width: 6),
                          Text(
                            targetDate == null
                                ? 'Target date (optional)'
                                : DateFormat.yMMMd().format(targetDate!),
                            style: lumaSans(size: 14, color: LumaColors.ink2),
                          ),
                        ],
                      ),
                    ),
                    if (lifeGoals.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        clipBehavior: Clip.none,
                        child: Row(
                          children: <Widget>[
                            LumaChip(
                              label: 'No link',
                              selected: linkedGoal == null,
                              onTap: () => setState(() => linkedGoal = null),
                            ),
                            for (final Goal goal in lifeGoals) ...<Widget>[
                              const SizedBox(width: 8),
                              LumaChip(
                                label: goal.title,
                                selected: linkedGoal?.id == goal.id,
                                onTap: () => setState(() => linkedGoal = goal),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    LumaPrimaryButton(
                      label: 'Create goal',
                      height: 52,
                      onTap: () async {
                        final String value = name.text.trim();
                        final double? amount = double.tryParse(target.text);
                        final String? userId =
                            ref.read(supabaseClientProvider).auth.currentUser?.id;
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
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FinancialGoalRow extends StatelessWidget {
  const _FinancialGoalRow({required this.goal, required this.linked});

  final FinancialGoal goal;
  final Goal? linked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(goal.name, style: lumaSerif(size: 22)),
          const SizedBox(height: 8),
          if (goal.targetAmount != null)
            Text(formatMoney(goal.targetAmount!),
                style: lumaSans(size: 15, weight: FontWeight.w500)),
          if (goal.targetDate != null) ...<Widget>[
            const SizedBox(height: 4),
            Text('By ${DateFormat.yMMMd().format(goal.targetDate!.toLocal())}',
                style: lumaSans(size: 12.5, color: LumaColors.ink3)),
          ],
          if (linked != null) ...<Widget>[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => context.go('/future/goal/${linked!.id}'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const LumaIcon(LumaIcons.link, size: 14, color: LumaColors.accent),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(linked!.title,
                        overflow: TextOverflow.ellipsis,
                        style: lumaSans(
                            size: 13, weight: FontWeight.w500, color: LumaColors.accent)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
