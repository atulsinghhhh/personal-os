import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/buttons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../luma/widgets/rows.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

/// Accounts list: hairline rows of name/type/balance, matching the Money
/// dashboard's account section but with the "New" action promoted to the
/// header.
class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialAccount>> accounts =
        ref.watch(moneyAccountsProvider);

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 52, 20, 110),
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text('Accounts', style: lumaSerif(size: 40, height: 1.05)),
              GestureDetector(
                onTap: () => showCreateAccountSheet(context, ref),
                child: Text('New',
                    style: lumaSans(
                        size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 28),
          accounts.when(
            loading: () => const SizedBox(height: 200),
            error: (Object error, _) => Text('Could not load accounts.',
                style: lumaSans(size: 14, color: LumaColors.ink3)),
            data: (List<FinancialAccount> all) {
              if (all.isEmpty) {
                return GestureDetector(
                  onTap: () => showCreateAccountSheet(context, ref),
                  child: Text('No accounts yet — add your first one.',
                      style: lumaSans(
                          size: 14, weight: FontWeight.w500, color: LumaColors.accent)),
                );
              }
              return Column(
                children: <Widget>[
                  for (final FinancialAccount account in all)
                    _AccountRow(account: account),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends ConsumerWidget {
  const _AccountRow({required this.account});

  final FinancialAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> balance = ref.watch(moneyAccountBalanceProvider(account.id));

    return LumaMetaRow(
      label: account.name,
      valueWidget: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Text(
            balance.value == null ? '…' : formatMoney(balance.value!),
            style: lumaSans(size: 14, weight: FontWeight.w500),
          ),
          const SizedBox(height: 2),
          Text(accountTypeLabel(account.type),
              style: lumaSans(size: 12, color: LumaColors.ink3)),
        ],
      ),
      onTap: () => context.go('/money/accounts/${account.id}'),
    );
  }
}

/// Create-account sheet: name, type, opening balance. Currency defaults to
/// the profile's default currency.
Future<void> showCreateAccountSheet(BuildContext context, WidgetRef ref) {
  final TextEditingController name = TextEditingController();
  final TextEditingController amount = TextEditingController();
  AccountType type = AccountType.bank;
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
                  const LumaEyebrow('New account'),
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
                      hintText: 'e.g. Main bank account',
                      hintStyle: lumaSerif(size: 26, height: 1.15, color: LumaColors.ink3),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    child: Row(
                      children: <Widget>[
                        for (final AccountType value in AccountType.values) ...<Widget>[
                          if (value != AccountType.values.first) const SizedBox(width: 8),
                          LumaChip(
                            label: accountTypeLabel(value),
                            selected: type == value,
                            onTap: () => setState(() => type = value),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  CurrencyInput(currencyCode: currency, controller: amount, autofocus: false),
                  const SizedBox(height: 24),
                  LumaPrimaryButton(
                    label: 'Create account',
                    height: 52,
                    onTap: () async {
                      final String value = name.text.trim();
                      final String? userId =
                          ref.read(supabaseClientProvider).auth.currentUser?.id;
                      if (value.isEmpty || userId == null) return;
                      final double opening = double.tryParse(amount.text) ?? 0;
                      final DateTime now = DateTime.now().toUtc();
                      await ref.read(financialAccountRepositoryProvider).create(
                            FinancialAccount(
                              id: const Uuid().v4(),
                              userId: userId,
                              name: value,
                              type: type,
                              openingBalance: Money(amount: opening, currency: currency),
                              isArchived: false,
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
