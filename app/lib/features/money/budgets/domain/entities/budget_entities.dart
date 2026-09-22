import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'budget_entities.freezed.dart';

enum BudgetPeriod { weekly, monthly, custom }

@freezed
abstract class Budget with _$Budget {
  const factory Budget({
    required String id,
    required String userId,
    required String name,
    required BudgetPeriod period,
    required DateTime periodStart,
    DateTime? periodEnd,
    required String currency,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Budget;
}

@freezed
abstract class BudgetItem with _$BudgetItem {
  const factory BudgetItem({
    required String id,
    required String userId,
    required String budgetId,
    required String categoryId,
    required Money plannedAmount,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _BudgetItem;
}
