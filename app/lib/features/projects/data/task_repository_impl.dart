import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/project_entities.dart';
import '../domain/repositories/project_repositories.dart';

String taskStatusToWire(TaskStatus status) => switch (status) {
      TaskStatus.inbox => 'inbox',
      TaskStatus.todo => 'todo',
      TaskStatus.inProgress => 'in_progress',
      TaskStatus.done => 'done',
      TaskStatus.cancelled => 'cancelled',
      TaskStatus.someday => 'someday',
    };

TaskStatus taskStatusFromWire(String value) => switch (value) {
      'inbox' => TaskStatus.inbox,
      'in_progress' => TaskStatus.inProgress,
      'done' => TaskStatus.done,
      'cancelled' => TaskStatus.cancelled,
      'someday' => TaskStatus.someday,
      _ => TaskStatus.todo,
    };

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Task>> watchAll() => _watchWhere(null);

  @override
  Stream<List<Task>> watchByProject(String projectId) {
    return _watchWhere(
      (db.$TasksTable t) => t.projectId.equals(projectId),
    );
  }

  @override
  Stream<List<Task>> watchScheduledForDate(DateTime date) {
    final DateTime dayStart = DateTime.utc(date.year, date.month, date.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));
    return _watchWhere(
      (db.$TasksTable t) =>
          t.scheduledDate.isBiggerOrEqualValue(dayStart) &
          t.scheduledDate.isSmallerThanValue(dayEnd),
    );
  }

  @override
  Stream<List<Task>> watchInbox() {
    return _watchWhere((db.$TasksTable t) => t.status.equals('inbox'));
  }

  Stream<List<Task>> _watchWhere(
    Expression<bool> Function(db.$TasksTable)? filter,
  ) {
    final SimpleSelectStatement<db.$TasksTable, db.Task> query =
        _db.select(_db.tasks)
          ..where((db.$TasksTable t) => t.deletedAt.isNull());
    if (filter != null) query.where(filter);
    query.orderBy(<OrderingTerm Function(db.$TasksTable)>[
      (db.$TasksTable t) => OrderingTerm.asc(t.sortOrder),
      (db.$TasksTable t) => OrderingTerm.desc(t.priority),
      (db.$TasksTable t) => OrderingTerm.asc(t.createdAt),
    ]);
    return query.watch().map(
          (List<db.Task> rows) => rows.map(toEntity).toList(growable: false),
        );
  }

  @override
  Future<Task?> getById(String id) async {
    final db.Task? row = await (_db.select(_db.tasks)
          ..where((db.$TasksTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : toEntity(row);
  }

  @override
  Future<void> create(Task task) => _write(task, 'insert');

  @override
  Future<void> update(Task task) => _write(task, 'update');

  @override
  Future<void> delete(String id) async {
    final Task? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  @override
  Stream<List<TaskDependency>> watchDependencies(String taskId) {
    return (_db.select(_db.taskDependencies)
          ..where((db.$TaskDependenciesTable t) => t.taskId.equals(taskId)))
        .watch()
        .map(
          (List<db.TaskDependency> rows) => rows
              .map(
                (db.TaskDependency row) => TaskDependency(
                  id: row.id,
                  userId: row.userId,
                  taskId: row.taskId,
                  dependsOnTaskId: row.dependsOnTaskId,
                  createdAt: row.createdAt,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> addDependency(TaskDependency dependency) async {
    await _db.transaction(() async {
      await _db.into(_db.taskDependencies).insertOnConflictUpdate(
            db.TaskDependenciesCompanion.insert(
              id: dependency.id,
              userId: dependency.userId,
              taskId: dependency.taskId,
              dependsOnTaskId: dependency.dependsOnTaskId,
              createdAt: dependency.createdAt,
              isDirty: const Value<bool>(true),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'task_dependencies',
        entityId: dependency.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': dependency.id,
          'user_id': dependency.userId,
          'task_id': dependency.taskId,
          'depends_on_task_id': dependency.dependsOnTaskId,
          'created_at': WireCodec.toWireTimestamp(dependency.createdAt),
        },
      );
    });
    _onWrite();
  }

  @override
  Future<void> removeDependency(String dependencyId) async {
    // task_dependencies is the one hard-deleted table (immutable link rows).
    await _db.transaction(() async {
      await (_db.delete(_db.taskDependencies)
            ..where(
              (db.$TaskDependenciesTable t) => t.id.equals(dependencyId),
            ))
          .go();
      await _outbox.enqueue(
        entityTable: 'task_dependencies',
        entityId: dependencyId,
        operation: 'delete',
        payload: <String, dynamic>{'id': dependencyId},
      );
    });
    _onWrite();
  }

  Future<void> _write(Task task, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.tasks).insertOnConflictUpdate(
            db.TasksCompanion.insert(
              id: task.id,
              userId: task.userId,
              projectId: Value<String?>(task.projectId),
              title: task.title,
              notes: Value<String?>(task.notes),
              status: Value<String>(taskStatusToWire(task.status)),
              priority: Value<int>(task.priority),
              dueDate: Value<DateTime?>(task.dueDate),
              scheduledDate: Value<DateTime?>(task.scheduledDate),
              estimateMinutes: Value<int?>(task.estimateMinutes),
              actualMinutes: Value<int>(task.actualMinutes),
              sortOrder: Value<int>(task.sortOrder),
              createdAt: task.createdAt,
              updatedAt: task.updatedAt,
              deletedAt: Value<DateTime?>(task.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'tasks',
        entityId: task.id,
        operation: operation,
        payload: toWire(task),
      );
    });
    _onWrite();
  }

  static Task toEntity(db.Task row) {
    return Task(
      id: row.id,
      userId: row.userId,
      projectId: row.projectId,
      title: row.title,
      notes: row.notes,
      status: taskStatusFromWire(row.status),
      priority: row.priority,
      dueDate: row.dueDate,
      scheduledDate: row.scheduledDate,
      estimateMinutes: row.estimateMinutes,
      actualMinutes: row.actualMinutes,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static Map<String, dynamic> toWire(Task task) {
    String? dateOnly(DateTime? value) =>
        value?.toIso8601String().substring(0, 10);

    return <String, dynamic>{
      'id': task.id,
      'user_id': task.userId,
      'project_id': task.projectId,
      'title': task.title,
      'notes': task.notes,
      'status': taskStatusToWire(task.status),
      'priority': task.priority,
      'due_date': dateOnly(task.dueDate),
      'scheduled_date': dateOnly(task.scheduledDate),
      'estimate_minutes': task.estimateMinutes,
      'actual_minutes': task.actualMinutes,
      'sort_order': task.sortOrder,
      'created_at': WireCodec.toWireTimestamp(task.createdAt),
      'updated_at': WireCodec.toWireTimestamp(task.updatedAt),
      'deleted_at': task.deletedAt == null
          ? null
          : WireCodec.toWireTimestamp(task.deletedAt!),
    };
  }
}
