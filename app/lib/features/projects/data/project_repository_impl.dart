import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/project_entities.dart';
import '../domain/repositories/project_repositories.dart';

String projectStatusToWire(ProjectStatus status) => switch (status) {
      ProjectStatus.active => 'active',
      ProjectStatus.paused => 'paused',
      ProjectStatus.completed => 'completed',
      ProjectStatus.archived => 'archived',
    };

ProjectStatus projectStatusFromWire(String value) => switch (value) {
      'paused' => ProjectStatus.paused,
      'completed' => ProjectStatus.completed,
      'archived' => ProjectStatus.archived,
      _ => ProjectStatus.active,
    };

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Project>> watchAll() => _watchWhere(null);

  @override
  Stream<List<Project>> watchByGoal(String goalId) {
    return _watchWhere((db.$ProjectsTable t) => t.goalId.equals(goalId));
  }

  @override
  Stream<List<Project>> watchByMilestone(String milestoneId) {
    return _watchWhere(
      (db.$ProjectsTable t) => t.milestoneId.equals(milestoneId),
    );
  }

  Stream<List<Project>> _watchWhere(
    Expression<bool> Function(db.$ProjectsTable)? filter,
  ) {
    final SimpleSelectStatement<db.$ProjectsTable, db.Project> query =
        _db.select(_db.projects)
          ..where((db.$ProjectsTable t) => t.deletedAt.isNull());
    if (filter != null) query.where(filter);
    query.orderBy(<OrderingTerm Function(db.$ProjectsTable)>[
      (db.$ProjectsTable t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.watch().map(
          (List<db.Project> rows) =>
              rows.map(toEntity).toList(growable: false),
        );
  }

  @override
  Future<Project?> getById(String id) async {
    final db.Project? row = await (_db.select(_db.projects)
          ..where((db.$ProjectsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : toEntity(row);
  }

  @override
  Future<void> create(Project project) => _write(project, 'insert');

  @override
  Future<void> update(Project project) => _write(project, 'update');

  @override
  Future<void> delete(String id) async {
    final Project? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(Project project, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.projects).insertOnConflictUpdate(
            db.ProjectsCompanion.insert(
              id: project.id,
              userId: project.userId,
              milestoneId: Value<String?>(project.milestoneId),
              goalId: Value<String?>(project.goalId),
              title: project.title,
              description: Value<String?>(project.description),
              status: Value<String>(projectStatusToWire(project.status)),
              createdAt: project.createdAt,
              updatedAt: project.updatedAt,
              deletedAt: Value<DateTime?>(project.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'projects',
        entityId: project.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': project.id,
          'user_id': project.userId,
          'milestone_id': project.milestoneId,
          'goal_id': project.goalId,
          'title': project.title,
          'description': project.description,
          'status': projectStatusToWire(project.status),
          'created_at': WireCodec.toWireTimestamp(project.createdAt),
          'updated_at': WireCodec.toWireTimestamp(project.updatedAt),
          'deleted_at': project.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(project.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Project toEntity(db.Project row) {
    return Project(
      id: row.id,
      userId: row.userId,
      milestoneId: row.milestoneId,
      goalId: row.goalId,
      title: row.title,
      description: row.description,
      status: projectStatusFromWire(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
