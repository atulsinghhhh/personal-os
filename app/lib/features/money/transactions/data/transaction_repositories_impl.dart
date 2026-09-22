import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/transaction_entities.dart';
import '../domain/repositories/transaction_repositories.dart';

String transactionKindToWire(TransactionKind kind) => switch (kind) {
      TransactionKind.expense => 'expense',
      TransactionKind.income => 'income',
      TransactionKind.transfer => 'transfer',
    };

TransactionKind transactionKindFromWire(String value) => switch (value) {
      'income' => TransactionKind.income,
      'transfer' => TransactionKind.transfer,
      _ => TransactionKind.expense,
    };

String transactionConflictStateToWire(TransactionConflictState state) =>
    switch (state) {
      TransactionConflictState.none => 'none',
      TransactionConflictState.pendingReview => 'pending_review',
      TransactionConflictState.resolved => 'resolved',
    };

TransactionConflictState transactionConflictStateFromWire(String value) =>
    switch (value) {
      'pending_review' => TransactionConflictState.pendingReview,
      'resolved' => TransactionConflictState.resolved,
      _ => TransactionConflictState.none,
    };

String categoryKindToWire(CategoryKind kind) => switch (kind) {
      CategoryKind.expense => 'expense',
      CategoryKind.income => 'income',
    };

CategoryKind categoryKindFromWire(String value) =>
    value == 'income' ? CategoryKind.income : CategoryKind.expense;

double _parseAmount(dynamic value) {
  if (value is num) return value.toDouble();
  return num.tryParse(value.toString())?.toDouble() ?? 0;
}

DateTime _parseTimestamp(dynamic value) =>
    DateTime.parse(value as String).toUtc();

/// Decodes a wire-format transaction row (from a conflict_queue payload or a
/// pulled server row) into the domain entity.
MoneyTransaction transactionFromWire(Map<String, dynamic> wire) {
  return MoneyTransaction(
    id: wire['id'] as String,
    userId: wire['user_id'] as String,
    accountId: wire['account_id'] as String,
    categoryId: wire['category_id'] as String?,
    projectId: wire['project_id'] as String?,
    goalId: wire['goal_id'] as String?,
    kind: transactionKindFromWire(wire['kind'] as String),
    amount: Money(
      amount: _parseAmount(wire['amount']),
      currency: wire['currency'] as String,
    ),
    occurredAt: _parseTimestamp(wire['occurred_at']),
    note: wire['note'] as String?,
    clientUpdatedAt: _parseTimestamp(wire['client_updated_at']),
    serverUpdatedAt: _parseTimestamp(wire['server_updated_at']),
    conflictState: transactionConflictStateFromWire(
      wire['conflict_state'] as String? ?? 'none',
    ),
    createdAt: _parseTimestamp(wire['created_at']),
    updatedAt: _parseTimestamp(wire['updated_at']),
    deletedAt:
        wire['deleted_at'] == null ? null : _parseTimestamp(wire['deleted_at']),
  );
}

/// Wire payload for a transaction row. `server_updated_at` is intentionally
/// never included — it is trigger-stamped server-side; the sync engine
/// strips it defensively too, but the repository never sends it.
Map<String, dynamic> _transactionToWire(MoneyTransaction transaction) {
  return <String, dynamic>{
    'id': transaction.id,
    'user_id': transaction.userId,
    'account_id': transaction.accountId,
    'category_id': transaction.categoryId,
    'project_id': transaction.projectId,
    'goal_id': transaction.goalId,
    'kind': transactionKindToWire(transaction.kind),
    'amount': transaction.amount.amount,
    'currency': transaction.amount.currency,
    'occurred_at': WireCodec.toWireTimestamp(transaction.occurredAt),
    'note': transaction.note,
    'client_updated_at':
        WireCodec.toWireTimestamp(transaction.clientUpdatedAt),
    'conflict_state': transactionConflictStateToWire(transaction.conflictState),
    'created_at': WireCodec.toWireTimestamp(transaction.createdAt),
    'updated_at': WireCodec.toWireTimestamp(transaction.updatedAt),
    'deleted_at': transaction.deletedAt == null
        ? null
        : WireCodec.toWireTimestamp(transaction.deletedAt!),
  };
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<MoneyTransaction>> watchRecent(int limit) {
    return _watchWhere(null, limit: limit);
  }

  @override
  Stream<List<MoneyTransaction>> watchByAccount(String accountId) {
    return _watchWhere(
      (db.$TransactionsTable t) => t.accountId.equals(accountId),
    );
  }

  @override
  Stream<List<MoneyTransaction>> watchByProject(String projectId) {
    return _watchWhere(
      (db.$TransactionsTable t) => t.projectId.equals(projectId),
    );
  }

  @override
  Stream<List<MoneyTransaction>> watchByGoal(String goalId) {
    return _watchWhere((db.$TransactionsTable t) => t.goalId.equals(goalId));
  }

  @override
  Stream<List<MoneyTransaction>> watchForRange(DateTime start, DateTime end) {
    return _watchWhere(
      (db.$TransactionsTable t) =>
          t.occurredAt.isBiggerOrEqualValue(start) &
          t.occurredAt.isSmallerThanValue(end),
    );
  }

  Stream<List<MoneyTransaction>> _watchWhere(
    Expression<bool> Function(db.$TransactionsTable)? filter, {
    int? limit,
  }) {
    final SimpleSelectStatement<db.$TransactionsTable, db.Transaction> query =
        _db.select(_db.transactions)
          ..where((db.$TransactionsTable t) => t.deletedAt.isNull());
    if (filter != null) query.where(filter);
    query.orderBy(<OrderingTerm Function(db.$TransactionsTable)>[
      (db.$TransactionsTable t) => OrderingTerm.desc(t.occurredAt),
    ]);
    if (limit != null) query.limit(limit);
    return query.watch().map(
          (List<db.Transaction> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<MoneyTransaction?> getById(String id) async {
    final db.Transaction? row = await (_db.select(_db.transactions)
          ..where((db.$TransactionsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(MoneyTransaction transaction) async {
    // The trigger stamps server_updated_at on arrival; use the client edit
    // time as a provisional local value until the push round-trip applies
    // the real server value.
    final MoneyTransaction toStore = transaction.copyWith(
      serverUpdatedAt: transaction.clientUpdatedAt,
      conflictState: TransactionConflictState.none,
    );
    await _db.transaction(() async {
      await _insertLocalRow(toStore, isDirty: true);
      await _outbox.enqueue(
        entityTable: 'transactions',
        entityId: toStore.id,
        operation: 'insert',
        payload: _transactionToWire(toStore),
      );
    });
    _onWrite();
  }

  @override
  Future<void> update(MoneyTransaction transaction) async {
    final db.Transaction? existing = await (_db.select(_db.transactions)
          ..where((db.$TransactionsTable t) => t.id.equals(transaction.id)))
        .getSingleOrNull();
    final DateTime baseServerUpdatedAt =
        existing?.serverUpdatedAt ?? transaction.serverUpdatedAt;
    await _persistUpdate(transaction, baseServerUpdatedAt);
  }

  @override
  Future<void> delete(String id) async {
    final MoneyTransaction? existing = await getById(id);
    if (existing == null) return;
    final DateTime now = DateTime.now().toUtc();
    await update(existing.copyWith(deletedAt: now, updatedAt: now));
  }

  Future<void> _persistUpdate(
    MoneyTransaction transaction,
    DateTime baseServerUpdatedAt,
  ) async {
    await _db.transaction(() async {
      await _insertLocalRow(transaction, isDirty: true);
      await _outbox.enqueue(
        entityTable: 'transactions',
        entityId: transaction.id,
        operation: 'update',
        payload: _transactionToWire(transaction),
        baseServerUpdatedAt: baseServerUpdatedAt,
      );
    });
    _onWrite();
  }

  Future<void> _insertLocalRow(
    MoneyTransaction transaction, {
    required bool isDirty,
  }) async {
    await _db.into(_db.transactions).insertOnConflictUpdate(
          db.TransactionsCompanion.insert(
            id: transaction.id,
            userId: transaction.userId,
            accountId: transaction.accountId,
            categoryId: Value<String?>(transaction.categoryId),
            projectId: Value<String?>(transaction.projectId),
            goalId: Value<String?>(transaction.goalId),
            kind: transactionKindToWire(transaction.kind),
            amount: transaction.amount.amount,
            currency: transaction.amount.currency,
            occurredAt: transaction.occurredAt,
            note: Value<String?>(transaction.note),
            clientUpdatedAt: transaction.clientUpdatedAt,
            serverUpdatedAt: transaction.serverUpdatedAt,
            conflictState: Value<String>(
              transactionConflictStateToWire(transaction.conflictState),
            ),
            createdAt: transaction.createdAt,
            updatedAt: transaction.updatedAt,
            deletedAt: Value<DateTime?>(transaction.deletedAt),
            isDirty: Value<bool>(isDirty),
            localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
          ),
        );
  }

  static MoneyTransaction _toEntity(db.Transaction row) {
    return MoneyTransaction(
      id: row.id,
      userId: row.userId,
      accountId: row.accountId,
      categoryId: row.categoryId,
      projectId: row.projectId,
      goalId: row.goalId,
      kind: transactionKindFromWire(row.kind),
      amount: Money(amount: row.amount, currency: row.currency),
      occurredAt: row.occurredAt,
      note: row.note,
      clientUpdatedAt: row.clientUpdatedAt,
      serverUpdatedAt: row.serverUpdatedAt,
      conflictState: transactionConflictStateFromWire(row.conflictState),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  // ------------------------------------------------------------ rollups --

  @override
  Future<List<Money>> totalSpentForProject(String projectId) {
    return _spentGroupedByCurrency(
      'project_id = ?',
      <Variable<Object>>[Variable<String>(projectId)],
    );
  }

  @override
  Future<List<Money>> totalSpentForGoal(String goalId) {
    return _spentGroupedByCurrency(
      'goal_id = ?',
      <Variable<Object>>[Variable<String>(goalId)],
    );
  }

  Future<List<Money>> _spentGroupedByCurrency(
    String whereClause,
    List<Variable<Object>> variables,
  ) async {
    final List<QueryRow> rows = await _db
        .customSelect(
          'SELECT currency, COALESCE(SUM(amount), 0) AS total '
          'FROM transactions '
          "WHERE deleted_at IS NULL AND kind = 'expense' AND $whereClause "
          'GROUP BY currency',
          variables: variables,
          readsFrom: <TableInfo<Table, Object?>>{_db.transactions},
        )
        .get();
    return rows
        .map(
          (QueryRow row) => Money(
            amount: row.read<double>('total'),
            currency: row.read<String>('currency'),
          ),
        )
        .toList(growable: false);
  }

  // ---------------------------------------------------------- conflicts --

  @override
  Stream<List<TransactionConflict>> watchUnresolvedConflicts() {
    return (_db.select(_db.conflictQueue)
          ..where(
            (db.$ConflictQueueTable t) =>
                t.entityTable.equals('transactions') & t.resolvedAt.isNull(),
          ))
        .watch()
        .map(
          (List<db.ConflictQueueData> rows) => rows
              .map(
                (db.ConflictQueueData row) => TransactionConflict(
                  id: row.id,
                  entityId: row.entityId,
                  localVersion: transactionFromWire(
                    jsonDecode(row.localPayload) as Map<String, dynamic>,
                  ),
                  serverVersion: transactionFromWire(
                    jsonDecode(row.serverPayload) as Map<String, dynamic>,
                  ),
                  detectedAt: row.detectedAt,
                  resolvedAt: row.resolvedAt,
                  resolution: row.resolution,
                ),
              )
              .toList(growable: false),
        );
  }

  @override
  Future<void> resolveConflictKeepLocal(String conflictId) async {
    final db.ConflictQueueData? row = await (_db.select(_db.conflictQueue)
          ..where((db.$ConflictQueueTable t) => t.id.equals(conflictId)))
        .getSingleOrNull();
    if (row == null) return;

    final Map<String, dynamic> localPayload =
        jsonDecode(row.localPayload) as Map<String, dynamic>;
    final Map<String, dynamic> serverPayload =
        jsonDecode(row.serverPayload) as Map<String, dynamic>;
    final DateTime baseServerUpdatedAt =
        _parseTimestamp(serverPayload['server_updated_at']);

    await _db.transaction(() async {
      await _outbox.enqueue(
        entityTable: 'transactions',
        entityId: row.entityId,
        operation: 'update',
        payload: localPayload,
        baseServerUpdatedAt: baseServerUpdatedAt,
      );
      await (_db.update(_db.transactions)
            ..where((db.$TransactionsTable t) => t.id.equals(row.entityId)))
          .write(
        const db.TransactionsCompanion(
          conflictState: Value<String>('none'),
          isDirty: Value<bool>(true),
        ),
      );
      await (_db.update(_db.conflictQueue)
            ..where((db.$ConflictQueueTable t) => t.id.equals(conflictId)))
          .write(
        db.ConflictQueueCompanion(
          resolution: const Value<String?>('keep_local'),
          resolvedAt: Value<DateTime?>(DateTime.now().toUtc()),
        ),
      );
    });
    _onWrite();
  }

  @override
  Future<void> resolveConflictKeepServer(String conflictId) async {
    final db.ConflictQueueData? row = await (_db.select(_db.conflictQueue)
          ..where((db.$ConflictQueueTable t) => t.id.equals(conflictId)))
        .getSingleOrNull();
    if (row == null) return;

    final Map<String, dynamic> serverPayload =
        jsonDecode(row.serverPayload) as Map<String, dynamic>;
    final MoneyTransaction serverEntity = transactionFromWire(serverPayload)
        .copyWith(conflictState: TransactionConflictState.none);

    await _db.transaction(() async {
      await _insertLocalRow(serverEntity, isDirty: false);
      await (_db.delete(_db.syncOutbox)
            ..where(
              (db.$SyncOutboxTable t) =>
                  t.entityId.equals(row.entityId) &
                  t.entityTable.equals('transactions') &
                  t.status.equals('conflict'),
            ))
          .go();
      await (_db.update(_db.conflictQueue)
            ..where((db.$ConflictQueueTable t) => t.id.equals(conflictId)))
          .write(
        db.ConflictQueueCompanion(
          resolution: const Value<String?>('keep_server'),
          resolvedAt: Value<DateTime?>(DateTime.now().toUtc()),
        ),
      );
    });
    _onWrite();
  }

  @override
  Future<void> resolveConflictMerged(
    String conflictId,
    MoneyTransaction merged,
  ) async {
    final db.ConflictQueueData? row = await (_db.select(_db.conflictQueue)
          ..where((db.$ConflictQueueTable t) => t.id.equals(conflictId)))
        .getSingleOrNull();
    if (row == null) return;

    final Map<String, dynamic> serverPayload =
        jsonDecode(row.serverPayload) as Map<String, dynamic>;
    final DateTime baseServerUpdatedAt =
        _parseTimestamp(serverPayload['server_updated_at']);

    await _db.transaction(() async {
      await (_db.delete(_db.syncOutbox)
            ..where(
              (db.$SyncOutboxTable t) =>
                  t.entityId.equals(row.entityId) &
                  t.entityTable.equals('transactions') &
                  t.status.equals('conflict'),
            ))
          .go();
      await (_db.update(_db.conflictQueue)
            ..where((db.$ConflictQueueTable t) => t.id.equals(conflictId)))
          .write(
        db.ConflictQueueCompanion(
          resolution: const Value<String?>('merged'),
          resolvedAt: Value<DateTime?>(DateTime.now().toUtc()),
        ),
      );
    });
    await _persistUpdate(
      merged.copyWith(conflictState: TransactionConflictState.none),
      baseServerUpdatedAt,
    );
  }
}

class DriftTransactionCategoryRepository
    implements TransactionCategoryRepository {
  DriftTransactionCategoryRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  static const List<String> _defaultExpenseCategories = <String>[
    'Housing',
    'Food',
    'Transport',
    'Shopping',
    'Health',
    'Education',
    'Entertainment',
    'Subscriptions',
    'Travel',
    'Technology',
    'Business',
    'Bills',
    'Family',
    'Personal',
    'Other',
  ];

  static const List<String> _defaultIncomeCategories = <String>[
    'Salary',
    'Freelance',
    'Business Income',
    'Other Income',
  ];

  @override
  Stream<List<TransactionCategory>> watchAll() {
    return (_db.select(_db.transactionCategories)
          ..where((db.$TransactionCategoriesTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$TransactionCategoriesTable)>[
            (db.$TransactionCategoriesTable t) => OrderingTerm.asc(t.name),
          ]))
        .watch()
        .map(
          (List<db.TransactionCategory> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<void> create(TransactionCategory category) =>
      _write(category, 'insert');

  @override
  Future<void> update(TransactionCategory category) =>
      _write(category, 'update');

  @override
  Future<void> delete(String id) async {
    final db.TransactionCategory? row = await (_db.select(
      _db.transactionCategories,
    )..where((db.$TransactionCategoriesTable t) => t.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await _write(
      _toEntity(row).copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  @override
  Future<void> seedDefaults(String userId, {required String currency}) async {
    final List<db.TransactionCategory> existing = await (_db.select(
      _db.transactionCategories,
    )..where(
            (db.$TransactionCategoriesTable t) =>
                t.deletedAt.isNull() & t.userId.equals(userId),
          ))
        .get();
    if (existing.isNotEmpty) return;

    const Uuid uuid = Uuid();
    final DateTime now = DateTime.now().toUtc();
    final List<TransactionCategory> defaults = <TransactionCategory>[
      for (final String name in _defaultExpenseCategories)
        TransactionCategory(
          id: uuid.v4(),
          userId: userId,
          name: name,
          kind: CategoryKind.expense,
          isSystem: true,
          createdAt: now,
          updatedAt: now,
        ),
      for (final String name in _defaultIncomeCategories)
        TransactionCategory(
          id: uuid.v4(),
          userId: userId,
          name: name,
          kind: CategoryKind.income,
          isSystem: true,
          createdAt: now,
          updatedAt: now,
        ),
    ];

    await _db.transaction(() async {
      for (final TransactionCategory category in defaults) {
        await _db.into(_db.transactionCategories).insertOnConflictUpdate(
              db.TransactionCategoriesCompanion.insert(
                id: category.id,
                userId: category.userId,
                name: category.name,
                kind: categoryKindToWire(category.kind),
                parentId: const Value<String?>(null),
                icon: const Value<String?>(null),
                color: const Value<String?>(null),
                isSystem: const Value<bool>(true),
                createdAt: category.createdAt,
                updatedAt: category.updatedAt,
                isDirty: const Value<bool>(true),
                localUpdatedAt: Value<DateTime?>(now),
              ),
            );
        await _outbox.enqueue(
          entityTable: 'transaction_categories',
          entityId: category.id,
          operation: 'insert',
          payload: _toWire(category),
        );
      }
    });
    _onWrite();
  }

  Future<void> _write(TransactionCategory category, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.transactionCategories).insertOnConflictUpdate(
            db.TransactionCategoriesCompanion.insert(
              id: category.id,
              userId: category.userId,
              name: category.name,
              kind: categoryKindToWire(category.kind),
              parentId: Value<String?>(category.parentId),
              icon: Value<String?>(category.icon),
              color: Value<String?>(category.color),
              isSystem: Value<bool>(category.isSystem),
              createdAt: category.createdAt,
              updatedAt: category.updatedAt,
              deletedAt: Value<DateTime?>(category.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'transaction_categories',
        entityId: category.id,
        operation: operation,
        payload: _toWire(category),
      );
    });
    _onWrite();
  }

  static Map<String, dynamic> _toWire(TransactionCategory category) {
    return <String, dynamic>{
      'id': category.id,
      'user_id': category.userId,
      'name': category.name,
      'kind': categoryKindToWire(category.kind),
      'parent_id': category.parentId,
      'icon': category.icon,
      'color': category.color,
      'is_system': category.isSystem,
      'created_at': WireCodec.toWireTimestamp(category.createdAt),
      'updated_at': WireCodec.toWireTimestamp(category.updatedAt),
      'deleted_at': category.deletedAt == null
          ? null
          : WireCodec.toWireTimestamp(category.deletedAt!),
    };
  }

  static TransactionCategory _toEntity(db.TransactionCategory row) {
    return TransactionCategory(
      id: row.id,
      userId: row.userId,
      name: row.name,
      kind: categoryKindFromWire(row.kind),
      parentId: row.parentId,
      icon: row.icon,
      color: row.color,
      isSystem: row.isSystem,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
