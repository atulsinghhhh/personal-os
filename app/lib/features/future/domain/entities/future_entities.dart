import 'package:freezed_annotation/freezed_annotation.dart';

part 'future_entities.freezed.dart';

@freezed
abstract class LifeArea with _$LifeArea {
  const factory LifeArea({
    required String id,
    required String userId,
    required String name,
    String? color,
    String? icon,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _LifeArea;
}

@freezed
abstract class Vision with _$Vision {
  const factory Vision({
    required String id,
    required String userId,
    String? lifeAreaId,
    required String title,
    String? description,
    int? horizonYears,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Vision;
}
