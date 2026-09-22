import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_entities.freezed.dart';

enum ProjectStatus { active, paused, completed, archived }

enum TaskStatus { inbox, todo, inProgress, done, cancelled, someday }

@freezed
abstract class Project with _$Project {
  const factory Project({
    required String id,
    required String userId,
    String? milestoneId,
    String? goalId,
    required String title,
    String? description,
    required ProjectStatus status,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Project;
}

@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String userId,
    String? projectId,
    required String title,
    String? notes,
    required TaskStatus status,
    required int priority,
    DateTime? dueDate,
    DateTime? scheduledDate,
    int? estimateMinutes,
    required int actualMinutes,
    required int sortOrder,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Task;
}

/// No updatedAt/deletedAt — mirrors Postgres, which hard-deletes this
/// simple link row rather than soft-deleting it.
@freezed
abstract class TaskDependency with _$TaskDependency {
  const factory TaskDependency({
    required String id,
    required String userId,
    required String taskId,
    required String dependsOnTaskId,
    required DateTime createdAt,
  }) = _TaskDependency;
}
