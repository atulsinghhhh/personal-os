import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'transaction_entities.freezed.dart';

enum TransactionKind { expense, income, transfer }

/// Named MoneyTransaction (not Transaction) to avoid colliding with Drift's
/// transaction API.
enum TransactionConflictState { none, pendingReview, resolved }

enum CategoryKind { expense, income }

@freezed
abstract class MoneyTransaction with _$MoneyTransaction {
  const factory MoneyTransaction({
    required String id,
    required String userId,
    required String accountId,
    String? categoryId,
    String? projectId,
    String? goalId,
    required TransactionKind kind,
    required Money amount,
    required DateTime occurredAt,
    String? note,
    required DateTime clientUpdatedAt,
    required DateTime serverUpdatedAt,
    required TransactionConflictState conflictState,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _MoneyTransaction;
}

@freezed
abstract class TransactionCategory with _$TransactionCategory {
  const factory TransactionCategory({
    required String id,
    required String userId,
    required String name,
    required CategoryKind kind,
    String? parentId,
    String? icon,
    String? color,
    required bool isSystem,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _TransactionCategory;
}

/// A transaction sync conflict awaiting user resolution: both versions in
/// full, surfaced by the conflict banner and resolved from Transaction
/// detail (keep mine / keep server's / merge).
@freezed
abstract class TransactionConflict with _$TransactionConflict {
  const factory TransactionConflict({
    required String id,
    required String entityId,
    required MoneyTransaction localVersion,
    required MoneyTransaction serverVersion,
    required DateTime detectedAt,
    DateTime? resolvedAt,
    String? resolution,
  }) = _TransactionConflict;
}
