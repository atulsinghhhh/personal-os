import 'package:freezed_annotation/freezed_annotation.dart';

part 'debt.freezed.dart';

enum PaymentFrequency { weekly, monthly, yearly }

/// Manual debt tracking. All figures are user-entered; the app performs only
/// transparent arithmetic on them and never gives lending advice.
@freezed
abstract class Debt with _$Debt {
  const factory Debt({
    required String id,
    required String userId,
    required String name,
    required double principal,
    required double currentBalance,
    required String currency,
    double? interestRatePercent,
    double? minimumPayment,
    required PaymentFrequency paymentFrequency,
    DateTime? dueDate,
    DateTime? startDate,
    DateTime? targetPayoffDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Debt;
}
