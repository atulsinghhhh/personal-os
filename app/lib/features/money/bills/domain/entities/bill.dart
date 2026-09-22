import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../../shared/models/money.dart';

part 'bill.freezed.dart';

/// How a bill repeats. `none` means a one-off bill; otherwise the app rolls
/// [Bill.dueDate] forward one period when the bill is marked paid.
enum BillRecurrence { none, weekly, monthly, yearly }

@freezed
abstract class Bill with _$Bill {
  const factory Bill({
    required String id,
    required String userId,
    required String name,
    required Money amount,
    required DateTime dueDate,
    required BillRecurrence recurrence,
    String? accountId,
    String? categoryId,
    int? reminderDaysBefore,
    DateTime? lastPaidAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Bill;
}
