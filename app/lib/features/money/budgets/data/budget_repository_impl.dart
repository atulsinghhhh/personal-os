import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/budget_entities.dart';
import '../domain/repositories/budget_repository.dart';

String budgetPeriodToWire(BudgetPeriod period) => switch (period) {
      BudgetPeriod.weekly => 'weekly',
      BudgetPeriod.monthly => 'monthly',
      BudgetPeriod.custom => 'custom',
    };

BudgetPeriod budgetPeriodFromWire(String value) => switch (value) {
      'weekly' => BudgetPeriod.weekly,
      'custom' => BudgetPeriod.custom,
      _ => BudgetPeriod.monthly,
    };

String _dateOnly(DateTime value) => value.toIso8601String().substring(0, 10);

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Budget>> watchAll() {
    return (_db.select(_db.budgets)
          ..where((db.$BudgetsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$BudgetsTable)>[
            (db.$BudgetsTable t) => OrderingTerm.desc(t.periodStart),
          ]))
        .watch()
        .map(
          (List<db.Budget> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Budget?> getById(String id) async {
    final db.Budget? row = await (_db.select(_db.budgets)
          ..where((db.$BudgetsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Budget budget) => _write(budget, 'insert');

  @override
  Future<void> update(Budget budget) => _write(budget, 'update');

  @override
  Future<void> delete(String id) async {
    final Budget? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(Budget budget, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.budgets).insertOnConflictUpdate(
            db.BudgetsCompanion.insert(
              id: budget.id,
              userId: budget.userId,
              name: budget.name,
              period: budgetPeriodToWire(budget.period),
              periodStart: budget.periodStart,
              periodEnd: Value<DateTime?>(budget.periodEnd),
              currency: budget.currency,
              createdAt: budget.createdAt,
              updatedAt: budget.updatedAt,
              deletedAt: Value<DateTime?>(budget.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'budgets',
        entityId: budget.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': budget.id,
          'user_id': budget.userId,
          'name': budget.name,
          'period': budgetPeriodToWire(budget.period),
          'period_start': _dateOnly(budget.periodStart),
          'period_end':
              budget.periodEnd == null ? null : _dateOnly(budget.periodEnd!),
          'currency': budget.currency,
          'created_at': WireCodec.toWireTimestamp(budget.createdAt),
          'updated_at': WireCodec.toWireTimestamp(budget.updatedAt),
          'deleted_at': budget.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(budget.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Budget _toEntity(db.Budget row) {
    return Budget(
      id: row.id,
      userId: row.userId,
      name: row.name,
      period: budgetPeriodFromWire(row.period),
      periodStart: row.periodStart,
      periodEnd: row.periodEnd,
      currency: row.currency,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // ------------------------------------------------------------- items --

  @override
  Stream<List<BudgetItem>> watchItems(String budgetId) {
    final SimpleSelectStatement<db.$BudgetItemsTable, db.BudgetItem>
        itemsQuery = _db.select(_db.budgetItems)
          ..where(
            (db.$BudgetItemsTable t) =>
                t.deletedAt.isNull() & t.budgetId.equals(budgetId),
          );
    final JoinedSelectStatement<HasResultSet, dynamic> query =
        itemsQuery.join(<Join<HasResultSet, dynamic>>[
      innerJoin(
        _db.budgets,
        _db.budgets.id.equalsExp(_db.budgetItems.budgetId),
      ),
    ]);
    return query.watch().map(
          (List<TypedResult> rows) => rows
              .map(
                (TypedResult row) => _itemToEntity(
                  row.readTable(_db.budgetItems),
                  row.readTable(_db.budgets).currency,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> upsertItem(BudgetItem item) async {
    await _db.transaction(() async {
      await _db.into(_db.budgetItems).insertOnConflictUpdate(
            db.BudgetItemsCompanion.insert(
              id: item.id,
              userId: item.userId,
              budgetId: item.budgetId,
              categoryId: item.categoryId,
              plannedAmount: item.plannedAmount.amount,
              createdAt: item.createdAt,
              updatedAt: item.updatedAt,
              deletedAt: Value<DateTime?>(item.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'budget_items',
        entityId: item.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': item.id,
          'user_id': item.userId,
          'budget_id': item.budgetId,
          'category_id': item.categoryId,
          'planned_amount': item.plannedAmount.amount,
          'created_at': WireCodec.toWireTimestamp(item.createdAt),
          'updated_at': WireCodec.toWireTimestamp(item.updatedAt),
          'deleted_at': item.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(item.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  @override
  Future<void> deleteItem(String id) async {
    final db.BudgetItem? row = await (_db.select(_db.budgetItems)
          ..where((db.$BudgetItemsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    // The item write path never touches the currency (it is derived from
    // the owning budget at read time), so a placeholder here is harmless.
    await upsertItem(
      _itemToEntity(row, '').copyWith(deletedAt: DateTime.now().toUtc()),
    );
  }

  static BudgetItem _itemToEntity(db.BudgetItem row, String currency) {
    return BudgetItem(
      id: row.id,
      userId: row.userId,
      budgetId: row.budgetId,
      categoryId: row.categoryId,
      plannedAmount: Money(amount: row.plannedAmount, currency: currency),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  @override
  Future<Money> spentForItem(BudgetItem item, Budget budget) async {
    final DateTime periodEnd = budget.periodEnd ?? _computeEnd(budget);

    final QueryRow? row = await _db
        .customSelect(
          'SELECT COALESCE(SUM(amount), 0) AS total '
          'FROM transactions '
          "WHERE deleted_at IS NULL AND kind = 'expense' "
          'AND category_id = ? AND currency = ? '
          'AND occurred_at >= ? AND occurred_at < ?',
          variables: <Variable<Object>>[
            Variable<String>(item.categoryId),
            Variable<String>(budget.currency),
            Variable<DateTime>(budget.periodStart),
            Variable<DateTime>(periodEnd),
          ],
          readsFrom: <TableInfo<Table, Object?>>{_db.transactions},
        )
        .getSingleOrNull();

    final double total = row?.read<double>('total') ?? 0;
    return Money(amount: total, currency: budget.currency);
  }

  static DateTime _computeEnd(Budget budget) {
    final DateTime start = budget.periodStart;
    return switch (budget.period) {
      BudgetPeriod.weekly => start.add(const Duration(days: 7)),
      BudgetPeriod.monthly =>
        DateTime.utc(start.year, start.month + 1, start.day),
      BudgetPeriod.custom => start.add(const Duration(days: 30)),
    };
  }
}
