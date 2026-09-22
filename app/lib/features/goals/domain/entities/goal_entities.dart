import 'package:freezed_annotation/freezed_annotation.dart';

part 'goal_entities.freezed.dart';

enum GoalStatus { active, paused, achieved, abandoned }

enum MilestoneStatus { pending, done }

@freezed
abstract class Goal with _$Goal {
  const factory Goal({
    required String id,
    required String userId,
    String? visionId,
    String? lifeAreaId,
    required String title,
    String? description,
    DateTime? targetDate,
    required GoalStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Goal;
}

@freezed
abstract class GoalMetric with _$GoalMetric {
  const factory GoalMetric({
    required String id,
    required String userId,
    required String goalId,
    required String name,
    String? unit,
    double? targetValue,
    required double currentValue,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _GoalMetric;
}

@freezed
abstract class Milestone with _$Milestone {
  const factory Milestone({
    required String id,
    required String userId,
    required String goalId,
    required String title,
    DateTime? targetDate,
    required MilestoneStatus status,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Milestone;
}
