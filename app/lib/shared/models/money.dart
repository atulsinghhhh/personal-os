import 'package:freezed_annotation/freezed_annotation.dart';

part 'money.freezed.dart';

/// Amount + currency, always together — currency is per-record by design
/// (never hardcoded), so every money-bearing field in the domain layer uses
/// this instead of a bare double.
@freezed
abstract class Money with _$Money {
  const factory Money({required double amount, required String currency}) =
      _Money;
}
