import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/note.dart';
import '../domain/repositories/note_repository.dart';

class DriftNoteRepository implements NoteRepository {
  DriftNoteRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Note>> watchAll() => _watchWhere(null);

  @override
  Stream<List<Note>> watchByProject(String projectId) {
    return _watchWhere((db.$NotesTable t) => t.projectId.equals(projectId));
  }

  @override
  Stream<List<Note>> watchByGoal(String goalId) {
    return _watchWhere((db.$NotesTable t) => t.goalId.equals(goalId));
  }

  @override
  Stream<List<Note>> watchByTask(String taskId) {
    return _watchWhere((db.$NotesTable t) => t.taskId.equals(taskId));
  }

  Stream<List<Note>> _watchWhere(
    Expression<bool> Function(db.$NotesTable)? filter,
  ) {
    final SimpleSelectStatement<db.$NotesTable, db.Note> query =
        _db.select(_db.notes)
          ..where((db.$NotesTable t) => t.deletedAt.isNull());
    if (filter != null) query.where(filter);
    query.orderBy(<OrderingTerm Function(db.$NotesTable)>[
      (db.$NotesTable t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.watch().map(
          (List<db.Note> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Note?> getById(String id) async {
    final db.Note? row = await (_db.select(_db.notes)
          ..where((db.$NotesTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Note note) => _write(note, 'insert');

  @override
  Future<void> update(Note note) => _write(note, 'update');

  @override
  Future<void> delete(String id) async {
    final Note? existing = await getById(id);
    if (existing == null) return;
    await _write(existing.copyWith(deletedAt: DateTime.now().toUtc()), 'update');
  }

  Future<void> _write(Note note, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.notes).insertOnConflictUpdate(
            db.NotesCompanion.insert(
              id: note.id,
              userId: note.userId,
              title: Value<String?>(note.title),
              body: Value<String?>(note.body),
              projectId: Value<String?>(note.projectId),
              goalId: Value<String?>(note.goalId),
              taskId: Value<String?>(note.taskId),
              createdAt: note.createdAt,
              updatedAt: note.updatedAt,
              deletedAt: Value<DateTime?>(note.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'notes',
        entityId: note.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': note.id,
          'user_id': note.userId,
          'title': note.title,
          'body': note.body,
          'project_id': note.projectId,
          'goal_id': note.goalId,
          'task_id': note.taskId,
          'created_at': WireCodec.toWireTimestamp(note.createdAt),
          'updated_at': WireCodec.toWireTimestamp(note.updatedAt),
          'deleted_at': note.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(note.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Note _toEntity(db.Note row) {
    return Note(
      id: row.id,
      userId: row.userId,
      title: row.title,
      body: row.body,
      projectId: row.projectId,
      goalId: row.goalId,
      taskId: row.taskId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
