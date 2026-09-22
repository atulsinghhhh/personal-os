import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/calendar_entities.dart';
import '../domain/repositories/calendar_repositories.dart';

class DriftCalendarEventRepository implements CalendarEventRepository {
  DriftCalendarEventRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<CalendarEvent>> watchForDate(DateTime date) {
    final DateTime dayStart = DateTime.utc(date.year, date.month, date.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));
    return watchForRange(dayStart, dayEnd);
  }

  @override
  Stream<List<CalendarEvent>> watchForRange(DateTime start, DateTime end) {
    return (_db.select(_db.calendarEvents)
          ..where(
            (db.$CalendarEventsTable t) =>
                t.deletedAt.isNull() &
                t.startAt.isSmallerThanValue(end) &
                t.endAt.isBiggerOrEqualValue(start),
          )
          ..orderBy(<OrderingTerm Function(db.$CalendarEventsTable)>[
            (db.$CalendarEventsTable t) => OrderingTerm.asc(t.startAt),
          ]))
        .watch()
        .map(
          (List<db.CalendarEvent> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<void> create(CalendarEvent event) => _write(event, 'insert');

  @override
  Future<void> update(CalendarEvent event) => _write(event, 'update');

  @override
  Future<void> delete(String id) async {
    final db.CalendarEvent? row = await (_db.select(_db.calendarEvents)
          ..where((db.$CalendarEventsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _write(
      _toEntity(row).copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(CalendarEvent event, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.calendarEvents).insertOnConflictUpdate(
            db.CalendarEventsCompanion.insert(
              id: event.id,
              userId: event.userId,
              title: event.title,
              startAt: event.startAt,
              endAt: event.endAt,
              allDay: Value<bool>(event.allDay),
              relatedTaskId: Value<String?>(event.relatedTaskId),
              createdAt: event.createdAt,
              updatedAt: event.updatedAt,
              deletedAt: Value<DateTime?>(event.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'calendar_events',
        entityId: event.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': event.id,
          'user_id': event.userId,
          'title': event.title,
          'start_at': WireCodec.toWireTimestamp(event.startAt),
          'end_at': WireCodec.toWireTimestamp(event.endAt),
          'all_day': event.allDay,
          'related_task_id': event.relatedTaskId,
          'created_at': WireCodec.toWireTimestamp(event.createdAt),
          'updated_at': WireCodec.toWireTimestamp(event.updatedAt),
          'deleted_at': event.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(event.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static CalendarEvent _toEntity(db.CalendarEvent row) {
    return CalendarEvent(
      id: row.id,
      userId: row.userId,
      title: row.title,
      startAt: row.startAt,
      endAt: row.endAt,
      allDay: row.allDay,
      relatedTaskId: row.relatedTaskId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}

class DriftTimeBlockRepository implements TimeBlockRepository {
  DriftTimeBlockRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<TimeBlock>> watchForDate(DateTime date) {
    final DateTime dayStart = DateTime.utc(date.year, date.month, date.day);
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));
    return (_db.select(_db.timeBlocks)
          ..where(
            (db.$TimeBlocksTable t) =>
                t.deletedAt.isNull() &
                t.date.isBiggerOrEqualValue(dayStart) &
                t.date.isSmallerThanValue(dayEnd),
          )
          ..orderBy(<OrderingTerm Function(db.$TimeBlocksTable)>[
            (db.$TimeBlocksTable t) => OrderingTerm.asc(t.startAt),
          ]))
        .watch()
        .map(
          (List<db.TimeBlock> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<void> create(TimeBlock block) => _write(block, 'insert');

  @override
  Future<void> update(TimeBlock block) => _write(block, 'update');

  @override
  Future<void> delete(String id) async {
    final db.TimeBlock? row = await (_db.select(_db.timeBlocks)
          ..where((db.$TimeBlocksTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _write(
      _toEntity(row).copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(TimeBlock block, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.timeBlocks).insertOnConflictUpdate(
            db.TimeBlocksCompanion.insert(
              id: block.id,
              userId: block.userId,
              taskId: Value<String?>(block.taskId),
              date: block.date,
              startAt: Value<DateTime?>(block.startAt),
              endAt: Value<DateTime?>(block.endAt),
              createdAt: block.createdAt,
              updatedAt: block.updatedAt,
              deletedAt: Value<DateTime?>(block.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'time_blocks',
        entityId: block.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': block.id,
          'user_id': block.userId,
          'task_id': block.taskId,
          'date': block.date.toIso8601String().substring(0, 10),
          'start_at': block.startAt == null
              ? null
              : WireCodec.toWireTimestamp(block.startAt!),
          'end_at': block.endAt == null
              ? null
              : WireCodec.toWireTimestamp(block.endAt!),
          'created_at': WireCodec.toWireTimestamp(block.createdAt),
          'updated_at': WireCodec.toWireTimestamp(block.updatedAt),
          'deleted_at': block.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(block.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static TimeBlock _toEntity(db.TimeBlock row) {
    return TimeBlock(
      id: row.id,
      userId: row.userId,
      taskId: row.taskId,
      date: row.date,
      startAt: row.startAt,
      endAt: row.endAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
