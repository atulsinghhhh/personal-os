import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/bill.dart';
import '../domain/repositories/bill_repository.dart';

String billRecurrenceToWire(BillRecurrence recurrence) => switch (recurrence) {
      BillRecurrence.none => 'none',
      BillRecurrence.weekly => 'weekly',
      BillRecurrence.monthly => 'monthly',
      BillRecurrence.yearly => 'yearly',
    };

BillRecurrence billRecurrenceFromWire(String value) => switch (value) {
      'none' => BillRecurrence.none,
      'weekly' => BillRecurrence.weekly,
      'yearly' => BillRecurrence.yearly,
      _ => BillRecurrence.monthly,
    };

String? _dateOnly(DateTime? value) =>
    value?.toIso8601String().substring(0, 10);

/// Adds [months] to a date-only value, clamping the day to the last day of
/// the target month (Jan 31 + 1 month = Feb 28/29).
DateTime addMonthsClamped(DateTime date, int months) {
  final int zeroBased = date.month - 1 + months;
  final int year = date.year + (zeroBased ~/ 12);
  final int month = (zeroBased % 12) + 1;
  // Day 0 of the following month is the last day of the target month.
  final int lastDay = DateTime.utc(year, month + 1, 0).day;
  final int day = date.day > lastDay ? lastDay : date.day;
  return DateTime.utc(year, month, day);
}

class DriftBillRepository implements BillRepository {
  DriftBillRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Bill>> watchAll() {
    return (_db.select(_db.bills)
          ..where((db.$BillsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$BillsTable)>[
            (db.$BillsTable t) => OrderingTerm.asc(t.dueDate),
          ]))
        .watch()
        .map(
          (List<db.Bill> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Stream<List<Bill>> watchUpcoming(int limit) {
    final DateTime now = DateTime.now();
    final DateTime cutoff = DateTime.utc(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
    return (_db.select(_db.bills)
          ..where(
            (db.$BillsTable t) =>
                t.deletedAt.isNull() &
                t.dueDate.isBiggerOrEqualValue(cutoff),
          )
          ..orderBy(<OrderingTerm Function(db.$BillsTable)>[
            (db.$BillsTable t) => OrderingTerm.asc(t.dueDate),
          ])
          ..limit(limit))
        .watch()
        .map(
          (List<db.Bill> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Bill?> getById(String id) async {
    final db.Bill? row = await (_db.select(_db.bills)
          ..where((db.$BillsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Bill bill) => _write(bill, 'insert');

  @override
  Future<void> update(Bill bill) => _write(bill, 'update');

  @override
  Future<void> delete(String id) async {
    final Bill? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  @override
  Future<void> markPaid(Bill bill, {required String userId}) async {
    final DateTime now = DateTime.now().toUtc();
    final DateTime nextDueDate = switch (bill.recurrence) {
      BillRecurrence.none => bill.dueDate,
      BillRecurrence.weekly => bill.dueDate.add(const Duration(days: 7)),
      BillRecurrence.monthly => addMonthsClamped(bill.dueDate, 1),
      BillRecurrence.yearly => addMonthsClamped(bill.dueDate, 12),
    };
    await update(
      bill.copyWith(
        lastPaidAt: now,
        dueDate: nextDueDate,
        updatedAt: now,
      ),
    );
  }

  Future<void> _write(Bill bill, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.bills).insertOnConflictUpdate(
            db.BillsCompanion.insert(
              id: bill.id,
              userId: bill.userId,
              name: bill.name,
              amount: bill.amount.amount,
              currency: bill.amount.currency,
              dueDate: bill.dueDate,
              recurrence: Value<String>(billRecurrenceToWire(bill.recurrence)),
              accountId: Value<String?>(bill.accountId),
              categoryId: Value<String?>(bill.categoryId),
              reminderDaysBefore: Value<int?>(bill.reminderDaysBefore),
              lastPaidAt: Value<DateTime?>(bill.lastPaidAt),
              createdAt: bill.createdAt,
              updatedAt: bill.updatedAt,
              deletedAt: Value<DateTime?>(bill.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'bills',
        entityId: bill.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': bill.id,
          'user_id': bill.userId,
          'name': bill.name,
          'amount': bill.amount.amount,
          'currency': bill.amount.currency,
          'due_date': _dateOnly(bill.dueDate),
          'recurrence': billRecurrenceToWire(bill.recurrence),
          'account_id': bill.accountId,
          'category_id': bill.categoryId,
          'reminder_days_before': bill.reminderDaysBefore,
          'last_paid_at': bill.lastPaidAt == null
              ? null
              : WireCodec.toWireTimestamp(bill.lastPaidAt!),
          'created_at': WireCodec.toWireTimestamp(bill.createdAt),
          'updated_at': WireCodec.toWireTimestamp(bill.updatedAt),
          'deleted_at': bill.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(bill.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Bill _toEntity(db.Bill row) {
    return Bill(
      id: row.id,
      userId: row.userId,
      name: row.name,
      amount: Money(amount: row.amount, currency: row.currency),
      dueDate: row.dueDate,
      recurrence: billRecurrenceFromWire(row.recurrence),
      accountId: row.accountId,
      categoryId: row.categoryId,
      reminderDaysBefore: row.reminderDaysBefore,
      lastPaidAt: row.lastPaidAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
