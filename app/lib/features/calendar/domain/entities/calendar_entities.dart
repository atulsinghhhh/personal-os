import 'package:freezed_annotation/freezed_annotation.dart';

part 'calendar_entities.freezed.dart';

@freezed
abstract class CalendarEvent with _$CalendarEvent {
  const factory CalendarEvent({
    required String id,
    required String userId,
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    required bool allDay,
    String? relatedTaskId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _CalendarEvent;
}

@freezed
abstract class TimeBlock with _$TimeBlock {
  const factory TimeBlock({
    required String id,
    required String userId,
    String? taskId,
    required DateTime date,
    DateTime? startAt,
    DateTime? endAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _TimeBlock;
}
