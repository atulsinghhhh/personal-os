import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../domain/entities/debt.dart';
import '../domain/repositories/debt_repository.dart';

String paymentFrequencyToWire(PaymentFrequency frequency) =>
    switch (frequency) {
      PaymentFrequency.weekly => 'weekly',
      PaymentFrequency.monthly => 'monthly',
      PaymentFrequency.yearly => 'yearly',
    };

PaymentFrequency paymentFrequencyFromWire(String value) => switch (value) {
      'weekly' => PaymentFrequency.weekly,
      'yearly' => PaymentFrequency.yearly,
      _ => PaymentFrequency.monthly,
    };

String? _dateOnly(DateTime? value) =>
    value?.toIso8601String().substring(0, 10);

class DriftDebtRepository implements DebtRepository {
  DriftDebtRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Debt>> watchAll() {
    return (_db.select(_db.debts)
          ..where((db.$DebtsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$DebtsTable)>[
            (db.$DebtsTable t) => OrderingTerm.desc(t.currentBalance),
          ]))
        .watch()
        .map(
          (List<db.Debt> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Debt?> getById(String id) async {
    final db.Debt? row = await (_db.select(_db.debts)
          ..where((db.$DebtsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Debt debt) => _write(debt, 'insert');

  @override
  Future<void> update(Debt debt) => _write(debt, 'update');

  @override
  Future<void> delete(String id) async {
    final Debt? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(Debt debt, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.debts).insertOnConflictUpdate(
            db.DebtsCompanion.insert(
              id: debt.id,
              userId: debt.userId,
              name: debt.name,
              principal: debt.principal,
              currentBalance: debt.currentBalance,
              currency: debt.currency,
              interestRatePercent:
                  Value<double?>(debt.interestRatePercent),
              minimumPayment: Value<double?>(debt.minimumPayment),
              paymentFrequency: Value<String>(
                paymentFrequencyToWire(debt.paymentFrequency),
              ),
              dueDate: Value<DateTime?>(debt.dueDate),
              startDate: Value<DateTime?>(debt.startDate),
              targetPayoffDate: Value<DateTime?>(debt.targetPayoffDate),
              createdAt: debt.createdAt,
              updatedAt: debt.updatedAt,
              deletedAt: Value<DateTime?>(debt.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'debts',
        entityId: debt.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': debt.id,
          'user_id': debt.userId,
          'name': debt.name,
          'principal': debt.principal,
          'current_balance': debt.currentBalance,
          'currency': debt.currency,
          'interest_rate_percent': debt.interestRatePercent,
          'minimum_payment': debt.minimumPayment,
          'payment_frequency':
              paymentFrequencyToWire(debt.paymentFrequency),
          'due_date': _dateOnly(debt.dueDate),
          'start_date': _dateOnly(debt.startDate),
          'target_payoff_date': _dateOnly(debt.targetPayoffDate),
          'created_at': WireCodec.toWireTimestamp(debt.createdAt),
          'updated_at': WireCodec.toWireTimestamp(debt.updatedAt),
          'deleted_at': debt.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(debt.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Debt _toEntity(db.Debt row) {
    return Debt(
      id: row.id,
      userId: row.userId,
      name: row.name,
      principal: row.principal,
      currentBalance: row.currentBalance,
      currency: row.currency,
      interestRatePercent: row.interestRatePercent,
      minimumPayment: row.minimumPayment,
      paymentFrequency: paymentFrequencyFromWire(row.paymentFrequency),
      dueDate: row.dueDate,
      startDate: row.startDate,
      targetPayoffDate: row.targetPayoffDate,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
