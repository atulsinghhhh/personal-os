import 'package:freezed_annotation/freezed_annotation.dart';

part 'focus_session.freezed.dart';

@freezed
abstract class FocusSession with _$FocusSession {
  const factory FocusSession({
    required String id,
    required String userId,
    String? taskId,
    required DateTime startedAt,
    DateTime? endedAt,
    int? durationMinutes,
    required bool wasCompleted,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _FocusSession;
}
