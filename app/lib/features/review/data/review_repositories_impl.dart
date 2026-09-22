import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/review_entities.dart';
import '../domain/repositories/review_repositories.dart';

String _dateOnly(DateTime value) => value.toIso8601String().substring(0, 10);

DateTime _dayStart(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

class DriftDailyReviewRepository implements DailyReviewRepository {
  DriftDailyReviewRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<DailyReview?> watchForDate(DateTime date) {
    final DateTime day = _dayStart(date);
    return (_db.select(_db.dailyReviews)
          ..where(
            (db.$DailyReviewsTable t) =>
                t.deletedAt.isNull() & t.date.equals(day),
          ))
        .watch()
        .map(
          (List<db.DailyReview> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Stream<List<DailyReview>> watchRecent(int limit) {
    return (_db.select(_db.dailyReviews)
          ..where((db.$DailyReviewsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$DailyReviewsTable)>[
            (db.$DailyReviewsTable t) => OrderingTerm.desc(t.date),
          ])
          ..limit(limit))
        .watch()
        .map(
          (List<db.DailyReview> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<void> upsert(DailyReview review) async {
    await _db.transaction(() async {
      await _db.into(_db.dailyReviews).insertOnConflictUpdate(
            db.DailyReviewsCompanion.insert(
              id: review.id,
              userId: review.userId,
              date: _dayStart(review.date),
              energy: Value<int?>(review.energy),
              focus: Value<int?>(review.focus),
              mood: Value<int?>(review.mood),
              accomplished: Value<String?>(review.accomplished),
              blockedBy: Value<String?>(review.blockedBy),
              changeTomorrow: Value<String?>(review.changeTomorrow),
              createdAt: review.createdAt,
              updatedAt: review.updatedAt,
              deletedAt: Value<DateTime?>(review.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'daily_reviews',
        entityId: review.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': review.id,
          'user_id': review.userId,
          'date': _dateOnly(review.date),
          'energy': review.energy,
          'focus': review.focus,
          'mood': review.mood,
          'accomplished': review.accomplished,
          'blocked_by': review.blockedBy,
          'change_tomorrow': review.changeTomorrow,
          'created_at': WireCodec.toWireTimestamp(review.createdAt),
          'updated_at': WireCodec.toWireTimestamp(review.updatedAt),
          'deleted_at': review.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(review.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static DailyReview _toEntity(db.DailyReview row) {
    return DailyReview(
      id: row.id,
      userId: row.userId,
      date: row.date,
      energy: row.energy,
      focus: row.focus,
      mood: row.mood,
      accomplished: row.accomplished,
      blockedBy: row.blockedBy,
      changeTomorrow: row.changeTomorrow,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}

class DriftWeeklyReviewRepository implements WeeklyReviewRepository {
  DriftWeeklyReviewRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<WeeklyReview?> watchForWeek(DateTime weekStart) {
    final DateTime day = _dayStart(weekStart);
    return (_db.select(_db.weeklyReviews)
          ..where(
            (db.$WeeklyReviewsTable t) =>
                t.deletedAt.isNull() & t.weekStart.equals(day),
          ))
        .watch()
        .map(
          (List<db.WeeklyReview> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> upsert(WeeklyReview review) async {
    await _db.transaction(() async {
      await _db.into(_db.weeklyReviews).insertOnConflictUpdate(
            db.WeeklyReviewsCompanion.insert(
              id: review.id,
              userId: review.userId,
              weekStart: _dayStart(review.weekStart),
              wentWell: Value<String?>(review.wentWell),
              wentPoorly: Value<String?>(review.wentPoorly),
              learned: Value<String?>(review.learned),
              stopDoing: Value<String?>(review.stopDoing),
              continueDoing: Value<String?>(review.continueDoing),
              nextWeekFocus: Value<String?>(review.nextWeekFocus),
              createdAt: review.createdAt,
              updatedAt: review.updatedAt,
              deletedAt: Value<DateTime?>(review.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'weekly_reviews',
        entityId: review.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': review.id,
          'user_id': review.userId,
          'week_start': _dateOnly(review.weekStart),
          'went_well': review.wentWell,
          'went_poorly': review.wentPoorly,
          'learned': review.learned,
          'stop_doing': review.stopDoing,
          'continue_doing': review.continueDoing,
          'next_week_focus': review.nextWeekFocus,
          'created_at': WireCodec.toWireTimestamp(review.createdAt),
          'updated_at': WireCodec.toWireTimestamp(review.updatedAt),
          'deleted_at': review.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(review.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static WeeklyReview _toEntity(db.WeeklyReview row) {
    return WeeklyReview(
      id: row.id,
      userId: row.userId,
      weekStart: row.weekStart,
      wentWell: row.wentWell,
      wentPoorly: row.wentPoorly,
      learned: row.learned,
      stopDoing: row.stopDoing,
      continueDoing: row.continueDoing,
      nextWeekFocus: row.nextWeekFocus,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}

class DriftMonthlyReviewRepository implements MonthlyReviewRepository {
  DriftMonthlyReviewRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<MonthlyReview?> watchForMonth(DateTime month) {
    final DateTime day = _dayStart(month);
    return (_db.select(_db.monthlyReviews)
          ..where(
            (db.$MonthlyReviewsTable t) =>
                t.deletedAt.isNull() & t.month.equals(day),
          ))
        .watch()
        .map(
          (List<db.MonthlyReview> rows) =>
              rows.isEmpty ? null : _toEntity(rows.first),
        );
  }

  @override
  Future<void> upsert(MonthlyReview review) async {
    await _db.transaction(() async {
      await _db.into(_db.monthlyReviews).insertOnConflictUpdate(
            db.MonthlyReviewsCompanion.insert(
              id: review.id,
              userId: review.userId,
              month: _dayStart(review.month),
              summary: Value<String?>(review.summary),
              whatMattered: Value<String?>(review.whatMattered),
              whatWastedTime: Value<String?>(review.whatWastedTime),
              whatWasWorthTheMoney:
                  Value<String?>(review.whatWasWorthTheMoney),
              changeNextMonth: Value<String?>(review.changeNextMonth),
              createdAt: review.createdAt,
              updatedAt: review.updatedAt,
              deletedAt: Value<DateTime?>(review.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'monthly_reviews',
        entityId: review.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': review.id,
          'user_id': review.userId,
          'month': _dateOnly(review.month),
          'summary': review.summary,
          'what_mattered': review.whatMattered,
          'what_wasted_time': review.whatWastedTime,
          'what_was_worth_the_money': review.whatWasWorthTheMoney,
          'change_next_month': review.changeNextMonth,
          'created_at': WireCodec.toWireTimestamp(review.createdAt),
          'updated_at': WireCodec.toWireTimestamp(review.updatedAt),
          'deleted_at': review.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(review.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static MonthlyReview _toEntity(db.MonthlyReview row) {
    return MonthlyReview(
      id: row.id,
      userId: row.userId,
      month: row.month,
      summary: row.summary,
      whatMattered: row.whatMattered,
      whatWastedTime: row.whatWastedTime,
      whatWasWorthTheMoney: row.whatWasWorthTheMoney,
      changeNextMonth: row.changeNextMonth,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
