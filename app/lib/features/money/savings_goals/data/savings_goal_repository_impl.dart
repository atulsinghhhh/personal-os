import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/savings_goal.dart';
import '../domain/repositories/savings_goal_repository.dart';

String? _dateOnly(DateTime? value) =>
    value?.toIso8601String().substring(0, 10);

class DriftSavingsGoalRepository implements SavingsGoalRepository {
  DriftSavingsGoalRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<SavingsGoal>> watchAll() {
    return (_db.select(_db.savingsGoals)
          ..where((db.$SavingsGoalsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$SavingsGoalsTable)>[
            (db.$SavingsGoalsTable t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch()
        .map(
          (List<db.SavingsGoal> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<SavingsGoal?> getById(String id) async {
    final db.SavingsGoal? row = await (_db.select(_db.savingsGoals)
          ..where((db.$SavingsGoalsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(SavingsGoal goal) => _write(goal, 'insert');

  @override
  Future<void> update(SavingsGoal goal) => _write(goal, 'update');

  @override
  Future<void> delete(String id) async {
    final SavingsGoal? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(SavingsGoal goal, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.savingsGoals).insertOnConflictUpdate(
            db.SavingsGoalsCompanion.insert(
              id: goal.id,
              userId: goal.userId,
              name: goal.name,
              targetAmount: goal.targetAmount.amount,
              currency: goal.targetAmount.currency,
              currentAmount: Value<double>(goal.currentAmount.amount),
              targetDate: Value<DateTime?>(goal.targetDate),
              linkedAccountId: Value<String?>(goal.linkedAccountId),
              createdAt: goal.createdAt,
              updatedAt: goal.updatedAt,
              deletedAt: Value<DateTime?>(goal.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'savings_goals',
        entityId: goal.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': goal.id,
          'user_id': goal.userId,
          'name': goal.name,
          'target_amount': goal.targetAmount.amount,
          'currency': goal.targetAmount.currency,
          'current_amount': goal.currentAmount.amount,
          'target_date': _dateOnly(goal.targetDate),
          'linked_account_id': goal.linkedAccountId,
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

  static SavingsGoal _toEntity(db.SavingsGoal row) {
    return SavingsGoal(
      id: row.id,
      userId: row.userId,
      name: row.name,
      targetAmount: Money(amount: row.targetAmount, currency: row.currency),
      currentAmount: Money(amount: row.currentAmount, currency: row.currency),
      targetDate: row.targetDate,
      linkedAccountId: row.linkedAccountId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
