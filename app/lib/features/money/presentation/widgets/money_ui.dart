import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/design_system/theme/theme_extensions.dart';
import '../../../../core/design_system/tokens/typography.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../../../../shared/models/money.dart';

/// Shared money-formatting helpers for the Money tab. Currency symbols are
/// always derived from the record's ISO code — never hardcoded.

String formatMoney(Money money) {
  final NumberFormat format = NumberFormat.simpleCurrency(
    name: money.currency,
  );
  return format.format(money.amount);
}

String accountTypeLabel(AccountType type) => switch (type) {
      AccountType.cash => 'Cash',
      AccountType.bank => 'Bank',
      AccountType.savings => 'Savings',
      AccountType.creditCard => 'Credit card',
      AccountType.wallet => 'Wallet',
      AccountType.investment => 'Investment',
      AccountType.other => 'Other',
    };

String transactionKindLabel(TransactionKind kind) => switch (kind) {
      TransactionKind.expense => 'Expense',
      TransactionKind.income => 'Income',
      TransactionKind.transfer => 'Transfer',
    };

/// Signed, colored amount text for a transaction row: income green with a
/// leading +, expense in the expense color with a leading −.
class SignedAmountText extends StatelessWidget {
  const SignedAmountText({
    super.key,
    required this.transaction,
    this.style,
  });

  final MoneyTransaction transaction;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final String formatted = formatMoney(transaction.amount);
    final (String text, Color? color) = switch (transaction.kind) {
      TransactionKind.income => (
          '+$formatted',
          context.semanticColors.income,
        ),
      TransactionKind.expense => (
          '−$formatted',
          context.semanticColors.expense,
        ),
      TransactionKind.transfer => (formatted, null),
    };
    return Text(
      text,
      style: (style ?? AppTypography.currencyMedium).copyWith(color: color),
    );
  }
}

/// Section label used across Money screens, matching Today's convention.
TextStyle moneySectionLabel(BuildContext context) {
  return AppTypography.labelMedium.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    letterSpacing: 1.2,
  );
}
