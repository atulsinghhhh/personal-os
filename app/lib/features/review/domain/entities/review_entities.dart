import 'package:freezed_annotation/freezed_annotation.dart';

part 'review_entities.freezed.dart';

@freezed
abstract class DailyReview with _$DailyReview {
  const factory DailyReview({
    required String id,
    required String userId,
    required DateTime date,
    int? energy,
    int? focus,
    int? mood,
    String? accomplished,
    String? blockedBy,
    String? changeTomorrow,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _DailyReview;
}

@freezed
abstract class WeeklyReview with _$WeeklyReview {
  const factory WeeklyReview({
    required String id,
    required String userId,
    required DateTime weekStart,
    String? wentWell,
    String? wentPoorly,
    String? learned,
    String? stopDoing,
    String? continueDoing,
    String? nextWeekFocus,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _WeeklyReview;
}

@freezed
abstract class MonthlyReview with _$MonthlyReview {
  const factory MonthlyReview({
    required String id,
    required String userId,
    required DateTime month,
    String? summary,
    String? whatMattered,
    String? whatWastedTime,
    String? whatWasWorthTheMoney,
    String? changeNextMonth,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _MonthlyReview;
}
