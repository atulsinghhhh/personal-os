import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/plan_entities.dart';
import '../domain/repositories/plan_repositories.dart';

List<String> _decodeIds(String json) {
  final dynamic decoded = jsonDecode(json);
  if (decoded is! List) return const <String>[];
  return decoded.map((dynamic e) => e.toString()).toList(growable: false);
}

String _dateOnly(DateTime value) => value.toIso8601String().substring(0, 10);

DateTime _dayStart(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class DriftDailyPlanRepository implements DailyPlanRepository {
  DriftDailyPlanRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<DailyPlan?> watchForDate(DateTime date) {
    final DateTime day = _dayStart(date);
    return (_db.select(_db.dailyPlans)
          ..where(
            (db.$DailyPlansTable t) =>
                t.deletedAt.isNull() & t.date.equals(day),
          ))
        .watch()
        .map(
          (List<db.DailyPlan> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> upsert(DailyPlan plan) async {
    await _db.transaction(() async {
      await _db.into(_db.dailyPlans).insertOnConflictUpdate(
            db.DailyPlansCompanion.insert(
              id: plan.id,
              userId: plan.userId,
              date: _dayStart(plan.date),
              intention: Value<String?>(plan.intention),
              taskIdsJson: Value<String>(jsonEncode(plan.taskIds)),
              createdAt: plan.createdAt,
              updatedAt: plan.updatedAt,
              deletedAt: Value<DateTime?>(plan.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'daily_plans',
        entityId: plan.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': plan.id,
          'user_id': plan.userId,
          'date': _dateOnly(plan.date),
          'intention': plan.intention,
          'task_ids': plan.taskIds,
          'created_at': WireCodec.toWireTimestamp(plan.createdAt),
          'updated_at': WireCodec.toWireTimestamp(plan.updatedAt),
          'deleted_at': plan.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(plan.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static DailyPlan _toEntity(db.DailyPlan row) {
    return DailyPlan(
      id: row.id,
      userId: row.userId,
      date: row.date,
      intention: row.intention,
      taskIds: _decodeIds(row.taskIdsJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}

class DriftWeeklyPlanRepository implements WeeklyPlanRepository {
  DriftWeeklyPlanRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<WeeklyPlan?> watchForWeek(DateTime weekStart) {
    final DateTime day = _dayStart(weekStart);
    return (_db.select(_db.weeklyPlans)
          ..where(
            (db.$WeeklyPlansTable t) =>
                t.deletedAt.isNull() & t.weekStart.equals(day),
          ))
        .watch()
        .map(
          (List<db.WeeklyPlan> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> upsert(WeeklyPlan plan) async {
    await _db.transaction(() async {
      await _db.into(_db.weeklyPlans).insertOnConflictUpdate(
            db.WeeklyPlansCompanion.insert(
              id: plan.id,
              userId: plan.userId,
              weekStart: _dayStart(plan.weekStart),
              focusGoalIdsJson: Value<String>(jsonEncode(plan.focusGoalIds)),
              outcomes: Value<String?>(plan.outcomes),
              reflection: Value<String?>(plan.reflection),
              createdAt: plan.createdAt,
              updatedAt: plan.updatedAt,
              deletedAt: Value<DateTime?>(plan.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'weekly_plans',
        entityId: plan.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': plan.id,
          'user_id': plan.userId,
          'week_start': _dateOnly(plan.weekStart),
          'focus_goal_ids': plan.focusGoalIds,
          'outcomes': plan.outcomes,
          'reflection': plan.reflection,
          'created_at': WireCodec.toWireTimestamp(plan.createdAt),
          'updated_at': WireCodec.toWireTimestamp(plan.updatedAt),
          'deleted_at': plan.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(plan.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static WeeklyPlan _toEntity(db.WeeklyPlan row) {
    return WeeklyPlan(
      id: row.id,
      userId: row.userId,
      weekStart: row.weekStart,
      focusGoalIds: _decodeIds(row.focusGoalIdsJson),
      outcomes: row.outcomes,
      reflection: row.reflection,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}

class DriftMonthlyPlanRepository implements MonthlyPlanRepository {
  DriftMonthlyPlanRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<MonthlyPlan?> watchForMonth(DateTime month) {
    final DateTime day = _dayStart(month);
    return (_db.select(_db.monthlyPlans)
          ..where(
            (db.$MonthlyPlansTable t) =>
                t.deletedAt.isNull() & t.month.equals(day),
          ))
        .watch()
        .map(
          (List<db.MonthlyPlan> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> upsert(MonthlyPlan plan) async {
    await _db.transaction(() async {
      await _db.into(_db.monthlyPlans).insertOnConflictUpdate(
            db.MonthlyPlansCompanion.insert(
              id: plan.id,
              userId: plan.userId,
              month: _dayStart(plan.month),
              theme: Value<String?>(plan.theme),
              goalIdsJson: Value<String>(jsonEncode(plan.goalIds)),
              createdAt: plan.createdAt,
              updatedAt: plan.updatedAt,
              deletedAt: Value<DateTime?>(plan.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'monthly_plans',
        entityId: plan.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': plan.id,
          'user_id': plan.userId,
          'month': _dateOnly(plan.month),
          'theme': plan.theme,
          'goal_ids': plan.goalIds,
          'created_at': WireCodec.toWireTimestamp(plan.createdAt),
          'updated_at': WireCodec.toWireTimestamp(plan.updatedAt),
          'deleted_at': plan.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(plan.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static MonthlyPlan _toEntity(db.MonthlyPlan row) {
    return MonthlyPlan(
      id: row.id,
      userId: row.userId,
      month: row.month,
      theme: row.theme,
      goalIds: _decodeIds(row.goalIdsJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}

class DriftYearlyPlanRepository implements YearlyPlanRepository {
  DriftYearlyPlanRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<YearlyPlan?> watchForYear(int year) {
    return (_db.select(_db.yearlyPlans)
          ..where(
            (db.$YearlyPlansTable t) =>
                t.deletedAt.isNull() & t.year.equals(year),
          ))
        .watch()
        .map(
          (List<db.YearlyPlan> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> upsert(YearlyPlan plan) async {
    await _db.transaction(() async {
      await _db.into(_db.yearlyPlans).insertOnConflictUpdate(
            db.YearlyPlansCompanion.insert(
              id: plan.id,
              userId: plan.userId,
              year: plan.year,
              theme: Value<String?>(plan.theme),
              visionIdsJson: Value<String>(jsonEncode(plan.visionIds)),
              createdAt: plan.createdAt,
              updatedAt: plan.updatedAt,
              deletedAt: Value<DateTime?>(plan.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'yearly_plans',
        entityId: plan.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': plan.id,
          'user_id': plan.userId,
          'year': plan.year,
          'theme': plan.theme,
          'vision_ids': plan.visionIds,
          'created_at': WireCodec.toWireTimestamp(plan.createdAt),
          'updated_at': WireCodec.toWireTimestamp(plan.updatedAt),
          'deleted_at': plan.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(plan.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static YearlyPlan _toEntity(db.YearlyPlan row) {
    return YearlyPlan(
      id: row.id,
      userId: row.userId,
      year: row.year,
      theme: row.theme,
      visionIds: _decodeIds(row.visionIdsJson),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
