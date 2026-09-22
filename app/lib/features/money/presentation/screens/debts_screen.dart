import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/models/money.dart';
import '../../debts/domain/entities/debt.dart';
import '../widgets/money_ui.dart';

final StreamProvider<List<Debt>> debtsProvider = StreamProvider<List<Debt>>((Ref ref) {
  return ref.watch(debtRepositoryProvider).watchAll();
});

/// Debts: total-owed headline, then a hairline row per debt with a paid-off
/// progress line and an update-balance action.
class DebtsScreen extends ConsumerWidget {
  const DebtsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Debt>> debts = ref.watch(debtsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Debt', style: lumaSerif(size: 40, height: 1.05)),
              GestureDetector(
                onTap: () => _showCreateSheet(context, ref),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          debts.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load debts.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<Debt> all) {
              if (all.isEmpty) {
                return Text('No debts tracked. Long may it last.',
                    style: lumaSans(size: 14, color: LumaColors.ink3));
              }

              final Map<String, double> totalByCurrency = <String, double>{};
              for (final Debt debt in all) {
                totalByCurrency.update(
                  debt.currency,
                  (double v) => v + debt.currentBalance,
                  ifAbsent: () => debt.currentBalance,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const LumaEyebrow('Total debt'),
                  const SizedBox(height: 10),
                  for (final MapEntry<String, double> entry in totalByCurrency.entries)
                    Text(formatMoney(Money(amount: entry.value, currency: entry.key)),
                        style: lumaSerif(size: LumaType.metric, height: 1)),
                  const SizedBox(height: 20),
                  for (final Debt debt in all) _DebtRow(debt: debt),
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
    final TextEditingController balance = TextEditingController();
    final TextEditingController rate = TextEditingController();
    final TextEditingController minimum = TextEditingController();
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
                const LumaEyebrow('New debt'),
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
                    hintText: 'e.g. Car loan',
                    hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                  ),
                ),
                const SizedBox(height: 16),
                CurrencyInput(currencyCode: currency, controller: balance, autofocus: false),
                const SizedBox(height: 16),
                TextField(
                  controller: rate,
                  keyboardType: TextInputType.number,
                  style: lumaSans(size: 15),
                  cursorColor: LumaColors.ink,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Interest rate % per year (optional)',
                    hintStyle: lumaSans(size: 15, color: LumaColors.ink3),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minimum,
                  keyboardType: TextInputType.number,
                  style: lumaSans(size: 15),
                  cursorColor: LumaColors.ink,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: 'Minimum payment (optional)',
                    hintStyle: lumaSans(size: 15, color: LumaColors.ink3),
                  ),
                ),
                const SizedBox(height: 24),
                LumaPrimaryButton(
                  label: 'Save debt',
                  height: 52,
                  onTap: () async {
                    final String? userId = ref.read(supabaseClientProvider).auth.currentUser?.id;
                    final double? value = double.tryParse(balance.text);
                    if (userId == null || name.text.trim().isEmpty || value == null || value <= 0) {
                      return;
                    }
                    final DateTime now = DateTime.now().toUtc();
                    await ref.read(debtRepositoryProvider).create(
                          Debt(
                            id: const Uuid().v4(),
                            userId: userId,
                            name: name.text.trim(),
                            principal: value,
                            currentBalance: value,
                            currency: currency,
                            interestRatePercent: double.tryParse(rate.text),
                            minimumPayment: double.tryParse(minimum.text),
                            paymentFrequency: PaymentFrequency.monthly,
                            createdAt: now,
                            updatedAt: now,
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

class _DebtRow extends ConsumerWidget {
  const _DebtRow({required this.debt});

  final Debt debt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double paidFraction = debt.principal <= 0
        ? 0
        : ((debt.principal - debt.currentBalance) / debt.principal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: LumaColors.hairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(debt.name, style: lumaSans(size: 16, weight: FontWeight.w500))),
              Text(formatMoney(Money(amount: debt.currentBalance, currency: debt.currency)),
                  style: lumaSans(size: 15, weight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),
          LumaProgressLine(value: paidFraction, height: 6),
          const SizedBox(height: 8),
          Text(
            '${(paidFraction * 100).toStringAsFixed(0)}% of the original '
            '${formatMoney(Money(amount: debt.principal, currency: debt.currency))} paid'
            '${debt.interestRatePercent == null ? '' : ' · ${debt.interestRatePercent}%/yr'}'
            '${debt.minimumPayment == null ? '' : ' · min ${formatMoney(Money(amount: debt.minimumPayment!, currency: debt.currency))}'}',
            style: lumaSans(size: 12.5, color: LumaColors.ink3),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => _showUpdateBalanceSheet(context, ref),
                child: Text('Update balance',
                    style: lumaSans(
                        size: 13, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => ref.read(debtRepositoryProvider).delete(debt.id),
                child: const LumaIcon(LumaIcons.close, size: 16, color: LumaColors.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showUpdateBalanceSheet(BuildContext context, WidgetRef ref) {
    final TextEditingController balance =
        TextEditingController(text: debt.currentBalance.toStringAsFixed(0));
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
                LumaEyebrow('Update balance — ${debt.name}'),
                const SizedBox(height: 16),
                CurrencyInput(currencyCode: debt.currency, controller: balance),
                const SizedBox(height: 24),
                LumaPrimaryButton(
                  label: 'Save',
                  height: 52,
                  onTap: () async {
                    final double? value = double.tryParse(balance.text);
                    if (value == null || value < 0) return;
                    await ref.read(debtRepositoryProvider).update(
                          debt.copyWith(currentBalance: value, updatedAt: DateTime.now().toUtc()),
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
