import 'package:freezed_annotation/freezed_annotation.dart';

part 'note.freezed.dart';

@freezed
abstract class Note with _$Note {
  const factory Note({
    required String id,
    required String userId,
    String? title,
    String? body,
    String? projectId,
    String? goalId,
    String? taskId,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Note;
}
