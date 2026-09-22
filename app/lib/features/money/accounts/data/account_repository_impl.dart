import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/financial_account.dart';
import '../domain/repositories/account_repository.dart';

String accountTypeToWire(AccountType type) => switch (type) {
      AccountType.cash => 'cash',
      AccountType.bank => 'bank',
      AccountType.savings => 'savings',
      AccountType.creditCard => 'credit_card',
      AccountType.wallet => 'wallet',
      AccountType.investment => 'investment',
      AccountType.other => 'other',
    };

AccountType accountTypeFromWire(String value) => switch (value) {
      'bank' => AccountType.bank,
      'savings' => AccountType.savings,
      'credit_card' => AccountType.creditCard,
      'wallet' => AccountType.wallet,
      'investment' => AccountType.investment,
      'other' => AccountType.other,
      _ => AccountType.cash,
    };

class DriftFinancialAccountRepository implements FinancialAccountRepository {
  DriftFinancialAccountRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<FinancialAccount>> watchAll({bool includeArchived = false}) {
    final SimpleSelectStatement<db.$FinancialAccountsTable, db.FinancialAccount>
        query = _db.select(_db.financialAccounts)
          ..where((db.$FinancialAccountsTable t) => t.deletedAt.isNull());
    if (!includeArchived) {
      query.where((db.$FinancialAccountsTable t) => t.isArchived.equals(false));
    }
    query.orderBy(<OrderingTerm Function(db.$FinancialAccountsTable)>[
      (db.$FinancialAccountsTable t) => OrderingTerm.asc(t.name),
    ]);
    return query.watch().map(
          (List<db.FinancialAccount> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<FinancialAccount?> getById(String id) async {
    final db.FinancialAccount? row = await (_db.select(_db.financialAccounts)
          ..where((db.$FinancialAccountsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(FinancialAccount account) => _write(account, 'insert');

  @override
  Future<void> update(FinancialAccount account) => _write(account, 'update');

  @override
  Future<void> delete(String id) async {
    final FinancialAccount? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  @override
  Future<Money> currentBalance(String accountId) async {
    final FinancialAccount? account = await getById(accountId);
    final String currency = account?.openingBalance.currency ?? 'USD';
    final double opening = account?.openingBalance.amount ?? 0;

    final QueryRow? row = await _db
        .customSelect(
          'SELECT '
          "COALESCE(SUM(CASE WHEN kind = 'income' THEN amount ELSE 0 END), 0) AS income_total, "
          "COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount ELSE 0 END), 0) AS expense_total "
          'FROM transactions '
          'WHERE deleted_at IS NULL AND account_id = ?',
          variables: <Variable<Object>>[Variable<String>(accountId)],
          readsFrom: <TableInfo<Table, Object?>>{_db.transactions},
        )
        .getSingleOrNull();

    final double income = row?.read<double>('income_total') ?? 0;
    final double expense = row?.read<double>('expense_total') ?? 0;

    return Money(amount: opening + income - expense, currency: currency);
  }

  Future<void> _write(FinancialAccount account, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.financialAccounts).insertOnConflictUpdate(
            db.FinancialAccountsCompanion.insert(
              id: account.id,
              userId: account.userId,
              name: account.name,
              type: accountTypeToWire(account.type),
              currency: account.openingBalance.currency,
              openingBalance:
                  Value<double>(account.openingBalance.amount),
              institutionName: Value<String?>(account.institutionName),
              isArchived: Value<bool>(account.isArchived),
              createdAt: account.createdAt,
              updatedAt: account.updatedAt,
              deletedAt: Value<DateTime?>(account.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'financial_accounts',
        entityId: account.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': account.id,
          'user_id': account.userId,
          'name': account.name,
          'type': accountTypeToWire(account.type),
          'currency': account.openingBalance.currency,
          'opening_balance': account.openingBalance.amount,
          'institution_name': account.institutionName,
          'is_archived': account.isArchived,
          'created_at': WireCodec.toWireTimestamp(account.createdAt),
          'updated_at': WireCodec.toWireTimestamp(account.updatedAt),
          'deleted_at': account.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(account.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static FinancialAccount _toEntity(db.FinancialAccount row) {
    return FinancialAccount(
      id: row.id,
      userId: row.userId,
      name: row.name,
      type: accountTypeFromWire(row.type),
      openingBalance: Money(amount: row.openingBalance, currency: row.currency),
      institutionName: row.institutionName,
      isArchived: row.isArchived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
