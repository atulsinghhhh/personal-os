import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/financial_goal.dart';
import '../domain/repositories/financial_goal_repository.dart';

String financialGoalTypeToWire(FinancialGoalType type) => switch (type) {
      FinancialGoalType.custom => 'custom',
      FinancialGoalType.savingsTarget => 'savings_target',
      FinancialGoalType.debtPayoff => 'debt_payoff',
      FinancialGoalType.netWorthTarget => 'net_worth_target',
      FinancialGoalType.incomeTarget => 'income_target',
    };

FinancialGoalType financialGoalTypeFromWire(String value) => switch (value) {
      'savings_target' => FinancialGoalType.savingsTarget,
      'debt_payoff' => FinancialGoalType.debtPayoff,
      'net_worth_target' => FinancialGoalType.netWorthTarget,
      'income_target' => FinancialGoalType.incomeTarget,
      _ => FinancialGoalType.custom,
    };

String? _dateOnly(DateTime? value) =>
    value?.toIso8601String().substring(0, 10);

class DriftFinancialGoalRepository implements FinancialGoalRepository {
  DriftFinancialGoalRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<FinancialGoal>> watchAll() => _watchWhere(null);

  @override
  Stream<List<FinancialGoal>> watchByLinkedGoal(String goalId) {
    return _watchWhere(
      (db.$FinancialGoalsTable t) => t.linkedGoalId.equals(goalId),
    );
  }

  Stream<List<FinancialGoal>> _watchWhere(
    Expression<bool> Function(db.$FinancialGoalsTable)? filter,
  ) {
    final SimpleSelectStatement<db.$FinancialGoalsTable, db.FinancialGoal>
        query = _db.select(_db.financialGoals)
          ..where((db.$FinancialGoalsTable t) => t.deletedAt.isNull());
    if (filter != null) query.where(filter);
    query.orderBy(<OrderingTerm Function(db.$FinancialGoalsTable)>[
      (db.$FinancialGoalsTable t) => OrderingTerm.desc(t.createdAt),
    ]);
    return query.watch().map(
          (List<db.FinancialGoal> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<FinancialGoal?> getById(String id) async {
    final db.FinancialGoal? row = await (_db.select(_db.financialGoals)
          ..where((db.$FinancialGoalsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(FinancialGoal goal) => _write(goal, 'insert');

  @override
  Future<void> update(FinancialGoal goal) => _write(goal, 'update');

  @override
  Future<void> delete(String id) async {
    final FinancialGoal? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(FinancialGoal goal, String operation) async {
    String currency = goal.targetAmount?.currency ?? '';
    if (currency.isEmpty) {
      final db.FinancialGoal? existing = await (_db.select(_db.financialGoals)
            ..where((db.$FinancialGoalsTable t) => t.id.equals(goal.id)))
          .getSingleOrNull();
      currency = existing?.currency ?? 'USD';
    }

    await _db.transaction(() async {
      await _db.into(_db.financialGoals).insertOnConflictUpdate(
            db.FinancialGoalsCompanion.insert(
              id: goal.id,
              userId: goal.userId,
              name: goal.name,
              goalType: Value<String>(financialGoalTypeToWire(goal.goalType)),
              targetAmount: Value<double?>(goal.targetAmount?.amount),
              currency: currency,
              targetDate: Value<DateTime?>(goal.targetDate),
              linkedGoalId: Value<String?>(goal.linkedGoalId),
              createdAt: goal.createdAt,
              updatedAt: goal.updatedAt,
              deletedAt: Value<DateTime?>(goal.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'financial_goals',
        entityId: goal.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': goal.id,
          'user_id': goal.userId,
          'name': goal.name,
          'goal_type': financialGoalTypeToWire(goal.goalType),
          'target_amount': goal.targetAmount?.amount,
          'currency': currency,
          'target_date': _dateOnly(goal.targetDate),
          'linked_goal_id': goal.linkedGoalId,
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

  static FinancialGoal _toEntity(db.FinancialGoal row) {
    return FinancialGoal(
      id: row.id,
      userId: row.userId,
      name: row.name,
      goalType: financialGoalTypeFromWire(row.goalType),
      targetAmount: row.targetAmount == null
          ? null
          : Money(amount: row.targetAmount!, currency: row.currency),
      targetDate: row.targetDate,
      linkedGoalId: row.linkedGoalId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
