import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'savings_goal.freezed.dart';

@freezed
abstract class SavingsGoal with _$SavingsGoal {
  const factory SavingsGoal({
    required String id,
    required String userId,
    required String name,
    required Money targetAmount,
    required Money currentAmount,
    DateTime? targetDate,
    String? linkedAccountId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _SavingsGoal;
}
