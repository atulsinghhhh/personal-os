import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/design_system/tokens/spacing.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../../../core/design_system/widgets/app_button.dart';
import '../../../../core/design_system/widgets/app_card.dart';
import '../../../../core/design_system/widgets/app_list_row.dart';
import '../../../../core/design_system/widgets/app_sheet.dart';
import '../../../../core/design_system/widgets/app_text_field.dart';
import '../../../../core/design_system/widgets/currency_input.dart';
import '../../../../core/design_system/widgets/state_widgets.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/providers/repository_providers.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

class AccountsListScreen extends ConsumerWidget {
  const AccountsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<FinancialAccount>> accounts =
        ref.watch(moneyAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCreateAccountSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Account'),
      ),
      body: accounts.when(
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
            ErrorStateView(message: 'Could not load accounts.'),
        data: (List<FinancialAccount> all) {
          if (all.isEmpty) {
            return EmptyStateView(
              message: 'No accounts yet — add your first one.',
              icon: Icons.account_balance_outlined,
              ctaLabel: 'Add an account',
              onCta: () => showCreateAccountSheet(context, ref),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: all.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (BuildContext context, int index) {
              final FinancialAccount account = all[index];
              return AppCard(
                padding: EdgeInsets.zero,
                child: AppListRow(
                  title: account.name,
                  subtitle: accountTypeLabel(account.type),
                  trailing: _BalanceText(accountId: account.id),
                  onTap: () => context.go('/money/accounts/${account.id}'),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _BalanceText extends ConsumerWidget {
  const _BalanceText({required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Money> balance =
        ref.watch(moneyAccountBalanceProvider(accountId));
    return Text(
      balance.value == null ? '…' : formatMoney(balance.value!),
      style: AppTypography.currencyMedium,
    );
  }
}

/// Create-account sheet: name, type, opening balance. Currency defaults to
/// the profile's default currency.
Future<void> showCreateAccountSheet(BuildContext context, WidgetRef ref) {
  final TextEditingController name = TextEditingController();
  final TextEditingController amount = TextEditingController();
  AccountType type = AccountType.bank;
  final String currency =
      ref.read(currentProfileProvider).value?.defaultCurrency ?? 'USD';

  return showAppBottomSheet<void>(
    context: context,
    title: 'New account',
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
                hint: 'e.g. Main bank account',
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<AccountType>(
                initialValue: type,
                items: <DropdownMenuItem<AccountType>>[
                  for (final AccountType value in AccountType.values)
                    DropdownMenuItem<AccountType>(
                      value: value,
                      child: Text(accountTypeLabel(value)),
                    ),
                ],
                onChanged: (AccountType? value) {
                  if (value != null) setState(() => type = value);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Opening balance ($currency)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              CurrencyInput(
                currencyCode: currency,
                controller: amount,
                autofocus: false,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                label: 'Create account',
                expand: true,
                onPressed: () async {
                  final String value = name.text.trim();
                  final String? userId = ref
                      .read(supabaseClientProvider)
                      .auth
                      .currentUser
                      ?.id;
                  if (value.isEmpty || userId == null) return;
                  final double opening = double.tryParse(amount.text) ?? 0;
                  final DateTime now = DateTime.now().toUtc();
                  await ref.read(financialAccountRepositoryProvider).create(
                        FinancialAccount(
                          id: const Uuid().v4(),
                          userId: userId,
                          name: value,
                          type: type,
                          openingBalance:
                              Money(amount: opening, currency: currency),
                          isArchived: false,
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
