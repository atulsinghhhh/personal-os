import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/routing/route_paths.dart';
import '../../../../luma/theme/tokens.dart';
import '../../../../luma/widgets/luma_icons.dart';
import '../../../../luma/widgets/primitives.dart';
import '../../../../shared/models/money.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../providers/money_providers.dart';
import '../widgets/money_ui.dart';

class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.accountId});

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<FinancialAccount?> account =
        ref.watch(moneyAccountByIdProvider(accountId));
    final AsyncValue<Money> balance = ref.watch(moneyAccountBalanceProvider(accountId));
    final AsyncValue<List<MoneyTransaction>> transactions =
        ref.watch(moneyAccountTransactionsProvider(accountId));
    final List<TransactionCategory> categories =
        ref.watch(moneyCategoriesProvider).value ?? <TransactionCategory>[];

    return Scaffold(
      backgroundColor: LumaColors.ground,
      body: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(
            child: Text('Could not load this account.',
                style: lumaSans(size: 14, color: LumaColors.ink3))),
        data: (FinancialAccount? data) {
          if (data == null) {
            return Center(
                child: Text('Account not found.',
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
                      : context.go('${RoutePaths.money}/accounts'),
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
              LumaEyebrow(accountTypeLabel(data.type)),
              const SizedBox(height: 10),
              Text(
                balance.value == null ? '…' : formatMoney(balance.value!),
                style: lumaSerif(size: LumaType.metric, height: 1),
              ),
              const SizedBox(height: 8),
              Text(
                'Opening balance ${formatMoney(data.openingBalance)}',
                style: lumaSans(size: 13, color: LumaColors.ink3),
              ),
              const SizedBox(height: 28),
              const LumaEyebrow('Transactions'),
              const SizedBox(height: 14),
              transactions.when(
                loading: () => const SizedBox(height: 160),
                error: (Object error, _) => Text('Could not load transactions.',
                    style: lumaSans(size: 14, color: LumaColors.ink3)),
                data: (List<MoneyTransaction> all) {
                  if (all.isEmpty) {
                    return Text('No transactions on this account yet.',
                        style: lumaSans(size: 14, color: LumaColors.ink3));
                  }
                  return Column(
                    children: <Widget>[
                      for (final MoneyTransaction transaction in all)
                        _TransactionRow(
                          transaction: transaction,
                          title: _titleFor(transaction, categories),
                        ),
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

  static String _titleFor(
    MoneyTransaction transaction,
    List<TransactionCategory> categories,
  ) {
    for (final TransactionCategory category in categories) {
      if (category.id == transaction.categoryId) return category.name;
    }
    final String? note = transaction.note;
    if (note != null && note.isNotEmpty) return note;
    return transactionKindLabel(transaction.kind);
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction, required this.title});

  final MoneyTransaction transaction;
  final String title;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/money/transactions/${transaction.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: LumaColors.hairline)),
        ),
        child: Row(
          children: <Widget>[
            MoneyLetterAvatar(label: title),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(title,
                      style: lumaSans(size: 14.5, weight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(DateFormat.yMMMd().format(transaction.occurredAt.toLocal()),
                      style: lumaSans(size: 12.5, color: LumaColors.ink3)),
                ],
              ),
            ),
            SignedAmountText(transaction: transaction),
          ],
        ),
      ),
    );
  }
}
