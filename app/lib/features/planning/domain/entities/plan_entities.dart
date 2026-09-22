import 'package:freezed_annotation/freezed_annotation.dart';

part 'plan_entities.freezed.dart';

@freezed
abstract class DailyPlan with _$DailyPlan {
  const factory DailyPlan({
    required String id,
    required String userId,
    required DateTime date,
    String? intention,
    required List<String> taskIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _DailyPlan;
}

@freezed
abstract class WeeklyPlan with _$WeeklyPlan {
  const factory WeeklyPlan({
    required String id,
    required String userId,
    required DateTime weekStart,
    required List<String> focusGoalIds,
    String? outcomes,
    String? reflection,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _WeeklyPlan;
}

@freezed
abstract class MonthlyPlan with _$MonthlyPlan {
  const factory MonthlyPlan({
    required String id,
    required String userId,
    required DateTime month,
    String? theme,
    required List<String> goalIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _MonthlyPlan;
}

@freezed
abstract class YearlyPlan with _$YearlyPlan {
  const factory YearlyPlan({
    required String id,
    required String userId,
    required int year,
    String? theme,
    required List<String> visionIds,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _YearlyPlan;
}
