import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'subscription.freezed.dart';

enum BillingCycle { weekly, monthly, yearly }

@freezed
abstract class Subscription with _$Subscription {
  const factory Subscription({
    required String id,
    required String userId,
    required String service,
    required Money amount,
    required BillingCycle billingCycle,
    DateTime? renewalDate,
    String? categoryId,
    String? accountId,
    String? cancellationNote,
    required bool isActive,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Subscription;
}

/// Transparent arithmetic: weekly = amount * 52 / 12, yearly = amount / 12.
double subscriptionMonthlyCost(Subscription s) => switch (s.billingCycle) {
      BillingCycle.weekly => s.amount.amount * 52 / 12,
      BillingCycle.monthly => s.amount.amount,
      BillingCycle.yearly => s.amount.amount / 12,
    };

/// Transparent arithmetic: weekly = amount * 52, monthly = amount * 12.
double subscriptionAnnualCost(Subscription s) => switch (s.billingCycle) {
      BillingCycle.weekly => s.amount.amount * 52,
      BillingCycle.monthly => s.amount.amount * 12,
      BillingCycle.yearly => s.amount.amount,
    };
