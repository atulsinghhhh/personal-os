import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/goal_entities.dart';
import '../domain/repositories/goal_repositories.dart';

String goalStatusToWire(GoalStatus status) => switch (status) {
      GoalStatus.active => 'active',
      GoalStatus.paused => 'paused',
      GoalStatus.achieved => 'achieved',
      GoalStatus.abandoned => 'abandoned',
    };

GoalStatus goalStatusFromWire(String value) => switch (value) {
      'paused' => GoalStatus.paused,
      'achieved' => GoalStatus.achieved,
      'abandoned' => GoalStatus.abandoned,
      _ => GoalStatus.active,
    };

String milestoneStatusToWire(MilestoneStatus status) => switch (status) {
      MilestoneStatus.pending => 'pending',
      MilestoneStatus.done => 'done',
    };

MilestoneStatus milestoneStatusFromWire(String value) => switch (value) {
      'done' => MilestoneStatus.done,
      _ => MilestoneStatus.pending,
    };

String? _dateOnly(DateTime? value) =>
    value?.toIso8601String().substring(0, 10);

class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Goal>> watchAll() => _watchWhere(null);

  @override
  Stream<List<Goal>> watchByLifeArea(String lifeAreaId) {
    return _watchWhere(
      (db.$GoalsTable t) => t.lifeAreaId.equals(lifeAreaId),
    );
  }

  @override
  Stream<List<Goal>> watchByVision(String visionId) {
    return _watchWhere((db.$GoalsTable t) => t.visionId.equals(visionId));
  }

  Stream<List<Goal>> _watchWhere(
    Expression<bool> Function(db.$GoalsTable)? filter,
  ) {
    final SimpleSelectStatement<db.$GoalsTable, db.Goal> query =
        _db.select(_db.goals)
          ..where((db.$GoalsTable t) => t.deletedAt.isNull());
    if (filter != null) query.where(filter);
    query.orderBy(<OrderingTerm Function(db.$GoalsTable)>[
      (db.$GoalsTable t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.watch().map(
          (List<db.Goal> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Goal?> getById(String id) async {
    final db.Goal? row = await (_db.select(_db.goals)
          ..where((db.$GoalsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Goal goal) => _write(goal, 'insert');

  @override
  Future<void> update(Goal goal) => _write(goal, 'update');

  @override
  Future<void> delete(String id) async {
    final Goal? existing = await getById(id);
    if (existing == null) return;
    await _write(existing.copyWith(deletedAt: DateTime.now().toUtc()), 'update');
  }

  Future<void> _write(Goal goal, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.goals).insertOnConflictUpdate(
            db.GoalsCompanion.insert(
              id: goal.id,
              userId: goal.userId,
              visionId: Value<String?>(goal.visionId),
              lifeAreaId: Value<String?>(goal.lifeAreaId),
              title: goal.title,
              description: Value<String?>(goal.description),
              targetDate: Value<DateTime?>(goal.targetDate),
              status: Value<String>(goalStatusToWire(goal.status)),
              createdAt: goal.createdAt,
              updatedAt: goal.updatedAt,
              deletedAt: Value<DateTime?>(goal.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'goals',
        entityId: goal.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': goal.id,
          'user_id': goal.userId,
          'vision_id': goal.visionId,
          'life_area_id': goal.lifeAreaId,
          'title': goal.title,
          'description': goal.description,
          'target_date': _dateOnly(goal.targetDate),
          'status': goalStatusToWire(goal.status),
          'created_at': WireCodec.toWireTimestamp(goal.createdAt),
          'updated_at': WireCodec.toWireTimestamp(goal.updatedAt),
          'deleted_at': goal.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(goal.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Goal _toEntity(db.Goal row) {
    return Goal(
      id: row.id,
      userId: row.userId,
      visionId: row.visionId,
      lifeAreaId: row.lifeAreaId,
      title: row.title,
      description: row.description,
      targetDate: row.targetDate,
      status: goalStatusFromWire(row.status),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // ----------------------------------------------------------- metrics --

  @override
  Stream<List<GoalMetric>> watchMetrics(String goalId) {
    return (_db.select(_db.goalMetrics)
          ..where(
            (db.$GoalMetricsTable t) =>
                t.deletedAt.isNull() & t.goalId.equals(goalId),
          )
          ..orderBy(<OrderingTerm Function(db.$GoalMetricsTable)>[
            (db.$GoalMetricsTable t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch()
        .map(
          (List<db.GoalMetric> rows) =>
              rows.map(_metricToEntity).toList(growable: false),
        );
  }

  @override
  Future<void> createMetric(GoalMetric metric) => _writeMetric(metric, 'insert');

  @override
  Future<void> updateMetric(GoalMetric metric) => _writeMetric(metric, 'update');

  @override
  Future<void> deleteMetric(String id) async {
    final db.GoalMetric? row = await (_db.select(_db.goalMetrics)
          ..where((db.$GoalMetricsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _writeMetric(
      _metricToEntity(row).copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _writeMetric(GoalMetric metric, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.goalMetrics).insertOnConflictUpdate(
            db.GoalMetricsCompanion.insert(
              id: metric.id,
              userId: metric.userId,
              goalId: metric.goalId,
              name: metric.name,
              unit: Value<String?>(metric.unit),
              targetValue: Value<double?>(metric.targetValue),
              currentValue: Value<double>(metric.currentValue),
              createdAt: metric.createdAt,
              updatedAt: metric.updatedAt,
              deletedAt: Value<DateTime?>(metric.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'goal_metrics',
        entityId: metric.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': metric.id,
          'user_id': metric.userId,
          'goal_id': metric.goalId,
          'name': metric.name,
          'unit': metric.unit,
          'target_value': metric.targetValue,
          'current_value': metric.currentValue,
          'created_at': WireCodec.toWireTimestamp(metric.createdAt),
          'updated_at': WireCodec.toWireTimestamp(metric.updatedAt),
          'deleted_at': metric.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(metric.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static GoalMetric _metricToEntity(db.GoalMetric row) {
    return GoalMetric(
      id: row.id,
      userId: row.userId,
      goalId: row.goalId,
      name: row.name,
      unit: row.unit,
      targetValue: row.targetValue,
      currentValue: row.currentValue,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // -------------------------------------------------------- milestones --

  @override
  Stream<List<Milestone>> watchMilestones(String goalId) {
    return (_db.select(_db.milestones)
          ..where(
            (db.$MilestonesTable t) =>
                t.deletedAt.isNull() & t.goalId.equals(goalId),
          )
          ..orderBy(<OrderingTerm Function(db.$MilestonesTable)>[
            (db.$MilestonesTable t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch()
        .map(
          (List<db.Milestone> rows) =>
              rows.map(_milestoneToEntity).toList(growable: false),
        );
  }

  @override
  Future<void> createMilestone(Milestone milestone) =>
      _writeMilestone(milestone, 'insert');

  @override
  Future<void> updateMilestone(Milestone milestone) =>
      _writeMilestone(milestone, 'update');

  @override
  Future<void> deleteMilestone(String id) async {
    final db.Milestone? row = await (_db.select(_db.milestones)
          ..where((db.$MilestonesTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _writeMilestone(
      _milestoneToEntity(row).copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _writeMilestone(Milestone milestone, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.milestones).insertOnConflictUpdate(
            db.MilestonesCompanion.insert(
              id: milestone.id,
              userId: milestone.userId,
              goalId: milestone.goalId,
              title: milestone.title,
              targetDate: Value<DateTime?>(milestone.targetDate),
              status: Value<String>(milestoneStatusToWire(milestone.status)),
              sortOrder: Value<int>(milestone.sortOrder),
              createdAt: milestone.createdAt,
              updatedAt: milestone.updatedAt,
              deletedAt: Value<DateTime?>(milestone.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'milestones',
        entityId: milestone.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': milestone.id,
          'user_id': milestone.userId,
          'goal_id': milestone.goalId,
          'title': milestone.title,
          'target_date': _dateOnly(milestone.targetDate),
          'status': milestoneStatusToWire(milestone.status),
          'sort_order': milestone.sortOrder,
          'created_at': WireCodec.toWireTimestamp(milestone.createdAt),
          'updated_at': WireCodec.toWireTimestamp(milestone.updatedAt),
          'deleted_at': milestone.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(milestone.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Milestone _milestoneToEntity(db.Milestone row) {
    return Milestone(
      id: row.id,
      userId: row.userId,
      goalId: row.goalId,
      title: row.title,
      targetDate: row.targetDate,
      status: milestoneStatusFromWire(row.status),
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
