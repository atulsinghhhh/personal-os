import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../luma/theme/tokens.dart';
import '../../accounts/domain/entities/financial_account.dart';
import '../../transactions/domain/entities/transaction_entities.dart';
import '../../../../shared/models/money.dart';

/// Shared money-formatting helpers for the Money tab. Currency symbols are
/// always derived from the record's ISO code — never hardcoded. INR (and
/// only INR) renders with Indian digit grouping (lakh/crore), matching the
/// design; every other currency keeps standard 3-digit grouping.

String _localeFor(String currency) => currency == 'INR' ? 'en_IN' : 'en_US';

String formatMoney(Money money) {
  final bool whole = money.amount == money.amount.roundToDouble();
  // simpleCurrency (not the bare `currency` constructor) is the variant that
  // resolves an actual symbol from the ISO code — `currency()` without an
  // explicit `symbol:` falls back to printing the code itself (e.g. "INR").
  final NumberFormat format = NumberFormat.simpleCurrency(
    locale: _localeFor(money.currency),
    name: money.currency,
    decimalDigits: whole ? 0 : 2,
  );
  return format.format(money.amount);
}

/// Compact form for tight spaces — e.g. "₹7.4L" for INR, "$12.3K" otherwise.
String formatMoneyCompact(Money money) {
  final NumberFormat format = NumberFormat.compactSimpleCurrency(
    locale: _localeFor(money.currency),
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

/// Signed, colored amount text for a transaction row: income in the positive
/// tone with a leading +, expense in the negative tone with a leading −.
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
      TransactionKind.income => ('+$formatted', LumaColors.positive),
      TransactionKind.expense => ('−$formatted', LumaColors.negative),
      TransactionKind.transfer => (formatted, null),
    };
    return Text(
      text,
      style: (style ?? lumaSans(size: 15, weight: FontWeight.w500))
          .copyWith(color: color),
    );
  }
}

/// First-letter avatar used for recent-transaction rows (design's circular
/// letter badges), colored by transaction kind.
class MoneyLetterAvatar extends StatelessWidget {
  const MoneyLetterAvatar({super.key, required this.label, this.size = 40});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final String letter = label.trim().isEmpty ? '?' : label.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: LumaColors.sunken,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(letter,
          style: lumaSans(size: 15, weight: FontWeight.w500, color: LumaColors.ink2)),
    );
  }
}
