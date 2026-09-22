import 'package:freezed_annotation/freezed_annotation.dart';

part 'net_worth.freezed.dart';

/// Per-currency assets/liabilities totals. Net for a currency is
/// `assets - liabilities`; currencies are never merged.
@freezed
abstract class NetWorthEntry with _$NetWorthEntry {
  const factory NetWorthEntry({
    required double assets,
    required double liabilities,
  }) = _NetWorthEntry;
}

/// A point-in-time record of the user's computed net worth, one per date.
@freezed
abstract class NetWorthSnapshot with _$NetWorthSnapshot {
  const factory NetWorthSnapshot({
    required String id,
    required String userId,
    required DateTime date,
    required Map<String, NetWorthEntry> breakdown,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _NetWorthSnapshot;
}
