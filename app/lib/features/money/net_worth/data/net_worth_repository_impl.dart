import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../domain/entities/net_worth.dart';
import '../domain/repositories/net_worth_repository.dart';

class DriftNetWorthRepository implements NetWorthRepository {
  DriftNetWorthRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<NetWorthSnapshot>> watchSnapshots() {
    return (_db.select(_db.netWorthSnapshots)
          ..where((db.$NetWorthSnapshotsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$NetWorthSnapshotsTable)>[
            (db.$NetWorthSnapshotsTable t) => OrderingTerm.asc(t.date),
          ]))
        .watch()
        .map(
          (List<db.NetWorthSnapshot> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<void> upsertSnapshot(NetWorthSnapshot snapshot) async {
    final Map<String, Map<String, double>> breakdownJson =
        snapshot.breakdown.map(
      (String currency, NetWorthEntry entry) =>
          MapEntry<String, Map<String, double>>(currency, <String, double>{
        'assets': entry.assets,
        'liabilities': entry.liabilities,
      }),
    );

    await _db.transaction(() async {
      await _db.into(_db.netWorthSnapshots).insertOnConflictUpdate(
            db.NetWorthSnapshotsCompanion.insert(
              id: snapshot.id,
              userId: snapshot.userId,
              date: snapshot.date,
              breakdown: jsonEncode(breakdownJson),
              createdAt: snapshot.createdAt,
              updatedAt: snapshot.updatedAt,
              deletedAt: Value<DateTime?>(snapshot.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'net_worth_snapshots',
        entityId: snapshot.id,
        operation: 'insert',
        payload: <String, dynamic>{
          'id': snapshot.id,
          'user_id': snapshot.userId,
          'date': snapshot.date.toIso8601String().substring(0, 10),
          // jsonb column: send the object, not a string.
          'breakdown': breakdownJson,
          'created_at': WireCodec.toWireTimestamp(snapshot.createdAt),
          'updated_at': WireCodec.toWireTimestamp(snapshot.updatedAt),
          'deleted_at': snapshot.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(snapshot.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  @override
  Future<Map<String, NetWorthEntry>> computeCurrent(String userId) async {
    final Map<String, double> assets = <String, double>{};
    final Map<String, double> liabilities = <String, double>{};
    void addAsset(String currency, double amount) =>
        assets.update(currency, (double v) => v + amount,
            ifAbsent: () => amount);
    void addLiability(String currency, double amount) =>
        liabilities.update(currency, (double v) => v + amount,
            ifAbsent: () => amount);

    // Account balances: opening balance + income − expense, per account.
    final List<db.FinancialAccount> accounts =
        await (_db.select(_db.financialAccounts)
              ..where(
                (db.$FinancialAccountsTable t) =>
                    t.deletedAt.isNull() & t.isArchived.equals(false),
              ))
            .get();

    for (final db.FinancialAccount account in accounts) {
      final QueryRow sums = await _db
          .customSelect(
            'SELECT '
            "COALESCE(SUM(CASE WHEN kind = 'income' THEN amount END), 0) AS income, "
            "COALESCE(SUM(CASE WHEN kind = 'expense' THEN amount END), 0) AS expense "
            'FROM transactions '
            'WHERE account_id = ? AND deleted_at IS NULL',
            variables: <Variable<Object>>[Variable<String>(account.id)],
          )
          .getSingle();
      final double balance = account.openingBalance +
          sums.read<double>('income') -
          sums.read<double>('expense');

      if (account.type == 'credit_card') {
        // A negative card balance is money owed.
        if (balance < 0) addLiability(account.currency, -balance);
      } else if (balance >= 0) {
        addAsset(account.currency, balance);
      } else {
        // Overdrawn non-card account counts as a liability.
        addLiability(account.currency, -balance);
      }
    }

    // Manual assets.
    final List<db.Asset> manualAssets = await (_db.select(_db.assets)
          ..where((db.$AssetsTable t) => t.deletedAt.isNull()))
        .get();
    for (final db.Asset asset in manualAssets) {
      addAsset(asset.currency, asset.value);
    }

    // Debts.
    final List<db.Debt> debts = await (_db.select(_db.debts)
          ..where((db.$DebtsTable t) => t.deletedAt.isNull()))
        .get();
    for (final db.Debt debt in debts) {
      addLiability(debt.currency, debt.currentBalance);
    }

    final Set<String> currencies = <String>{
      ...assets.keys,
      ...liabilities.keys,
    };
    return <String, NetWorthEntry>{
      for (final String currency in currencies)
        currency: NetWorthEntry(
          assets: assets[currency] ?? 0,
          liabilities: liabilities[currency] ?? 0,
        ),
    };
  }

  static NetWorthSnapshot _toEntity(db.NetWorthSnapshot row) {
    final Map<String, dynamic> decoded =
        jsonDecode(row.breakdown) as Map<String, dynamic>;
    return NetWorthSnapshot(
      id: row.id,
      userId: row.userId,
      date: row.date,
      breakdown: decoded.map((String currency, dynamic value) {
        final Map<String, dynamic> entry = value as Map<String, dynamic>;
        return MapEntry<String, NetWorthEntry>(
          currency,
          NetWorthEntry(
            assets: (entry['assets'] as num?)?.toDouble() ?? 0,
            liabilities: (entry['liabilities'] as num?)?.toDouble() ?? 0,
          ),
        );
      }),
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
