import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'financial_goal.freezed.dart';

/// Only custom/savingsTarget are exercised by the Phase 1 UI; the other
/// values exist so Phase 2 needs no migration.
enum FinancialGoalType {
  custom,
  savingsTarget,
  debtPayoff,
  netWorthTarget,
  incomeTarget,
}

@freezed
abstract class FinancialGoal with _$FinancialGoal {
  const factory FinancialGoal({
    required String id,
    required String userId,
    required String name,
    required FinancialGoalType goalType,
    Money? targetAmount,
    DateTime? targetDate,
    String? linkedGoalId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _FinancialGoal;
}
