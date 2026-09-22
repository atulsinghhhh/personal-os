import '../entities/note.dart';

abstract class NoteRepository {
  Stream<List<Note>> watchAll();
  Stream<List<Note>> watchByProject(String projectId);
  Stream<List<Note>> watchByGoal(String goalId);
  Stream<List<Note>> watchByTask(String taskId);
  Future<Note?> getById(String id);
  Future<void> create(Note note);
  Future<void> update(Note note);
  Future<void> delete(String id);
}
