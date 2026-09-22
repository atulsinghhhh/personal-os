import 'package:freezed_annotation/freezed_annotation.dart';

part 'asset.freezed.dart';

/// A manually tracked asset (vehicle, property, valuables). The value is
/// user-entered; the app never estimates or updates it on its own.
@freezed
abstract class Asset with _$Asset {
  const factory Asset({
    required String id,
    required String userId,
    required String name,
    required double value,
    required String currency,
    String? note,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Asset;
}
