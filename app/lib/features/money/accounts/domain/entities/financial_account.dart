import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'financial_account.freezed.dart';

enum AccountType { cash, bank, savings, creditCard, wallet, investment, other }

@freezed
abstract class FinancialAccount with _$FinancialAccount {
  const factory FinancialAccount({
    required String id,
    required String userId,
    required String name,
    required AccountType type,
    required Money openingBalance,
    String? institutionName,
    required bool isArchived,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _FinancialAccount;
}
