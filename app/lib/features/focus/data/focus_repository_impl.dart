import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/focus_session.dart';
import '../domain/repositories/focus_repository.dart';

class DriftFocusSessionRepository implements FocusSessionRepository {
  DriftFocusSessionRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<FocusSession>> watchByTask(String taskId) {
    return (_db.select(_db.focusSessions)
          ..where(
            (db.$FocusSessionsTable t) =>
                t.deletedAt.isNull() & t.taskId.equals(taskId),
          )
          ..orderBy(<OrderingTerm Function(db.$FocusSessionsTable)>[
            (db.$FocusSessionsTable t) => OrderingTerm.desc(t.startedAt),
          ]))
        .watch()
        .map(
          (List<db.FocusSession> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Stream<List<FocusSession>> watchForDateRange(DateTime start, DateTime end) {
    return (_db.select(_db.focusSessions)
          ..where(
            (db.$FocusSessionsTable t) =>
                t.deletedAt.isNull() &
                t.startedAt.isBiggerOrEqualValue(start) &
                t.startedAt.isSmallerThanValue(end),
          )
          ..orderBy(<OrderingTerm Function(db.$FocusSessionsTable)>[
            (db.$FocusSessionsTable t) => OrderingTerm.asc(t.startedAt),
          ]))
        .watch()
        .map(
          (List<db.FocusSession> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Stream<FocusSession?> watchActive() {
    return (_db.select(_db.focusSessions)
          ..where(
            (db.$FocusSessionsTable t) =>
                t.deletedAt.isNull() & t.endedAt.isNull(),
          )
          ..orderBy(<OrderingTerm Function(db.$FocusSessionsTable)>[
            (db.$FocusSessionsTable t) => OrderingTerm.desc(t.startedAt),
          ])
          ..limit(1))
        .watch()
        .map(
          (List<db.FocusSession> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> create(FocusSession session) => _write(session, 'insert');

  @override
  Future<void> update(FocusSession session) => _write(session, 'update');

  @override
  Future<void> delete(String id) async {
    final db.FocusSession? row = await (_db.select(_db.focusSessions)
          ..where((db.$FocusSessionsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _write(
      _toEntity(row).copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  @override
  Future<int> totalMinutesForTask(String taskId) async {
    final QueryRow? row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(duration_minutes), 0) AS total '
          'FROM focus_sessions '
          'WHERE deleted_at IS NULL AND task_id = ?',
          variables: <Variable<Object>>[Variable<String>(taskId)],
          readsFrom: <TableInfo<Table, Object?>>{_db.focusSessions},
        )
        .getSingleOrNull();
    return row?.read<int>('total') ?? 0;
  }

  @override
  Future<int> totalMinutesForProject(String projectId) async {
    final QueryRow? row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(fs.duration_minutes), 0) AS total '
          'FROM focus_sessions fs '
          'JOIN tasks t ON t.id = fs.task_id '
          'WHERE fs.deleted_at IS NULL AND t.project_id = ?',
          variables: <Variable<Object>>[Variable<String>(projectId)],
          readsFrom: <TableInfo<Table, Object?>>{
            _db.focusSessions,
            _db.tasks,
          },
        )
        .getSingleOrNull();
    return row?.read<int>('total') ?? 0;
  }

  @override
  Future<int> totalMinutesForGoal(String goalId) async {
    final QueryRow? row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(fs.duration_minutes), 0) AS total '
          'FROM focus_sessions fs '
          'JOIN tasks t ON t.id = fs.task_id '
          'JOIN projects p ON p.id = t.project_id '
          'WHERE fs.deleted_at IS NULL AND p.goal_id = ?',
          variables: <Variable<Object>>[Variable<String>(goalId)],
          readsFrom: <TableInfo<Table, Object?>>{
            _db.focusSessions,
            _db.tasks,
            _db.projects,
          },
        )
        .getSingleOrNull();
    return row?.read<int>('total') ?? 0;
  }

  Future<void> _write(FocusSession session, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.focusSessions).insertOnConflictUpdate(
            db.FocusSessionsCompanion.insert(
              id: session.id,
              userId: session.userId,
              taskId: Value<String?>(session.taskId),
              startedAt: session.startedAt,
              endedAt: Value<DateTime?>(session.endedAt),
              durationMinutes: Value<int?>(session.durationMinutes),
              wasCompleted: Value<bool>(session.wasCompleted),
              createdAt: session.createdAt,
              updatedAt: session.updatedAt,
              deletedAt: Value<DateTime?>(session.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'focus_sessions',
        entityId: session.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': session.id,
          'user_id': session.userId,
          'task_id': session.taskId,
          'started_at': WireCodec.toWireTimestamp(session.startedAt),
          'ended_at': session.endedAt == null
              ? null
              : WireCodec.toWireTimestamp(session.endedAt!),
          'duration_minutes': session.durationMinutes,
          'was_completed': session.wasCompleted,
          'created_at': WireCodec.toWireTimestamp(session.createdAt),
          'updated_at': WireCodec.toWireTimestamp(session.updatedAt),
          'deleted_at': session.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(session.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static FocusSession _toEntity(db.FocusSession row) {
    return FocusSession(
      id: row.id,
      userId: row.userId,
      taskId: row.taskId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      durationMinutes: row.durationMinutes,
      wasCompleted: row.wasCompleted,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
