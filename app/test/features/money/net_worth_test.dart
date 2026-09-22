import 'package:app/data/local/database.dart'
    show
        AppDatabase,
        AssetsCompanion,
        DebtsCompanion,
        FinancialAccountsCompanion,
        TransactionsCompanion;
import 'package:app/core/sync/outbox/outbox_writer.dart';
import 'package:app/features/money/net_worth/data/net_worth_repository_impl.dart';
import 'package:app/features/money/net_worth/domain/entities/net_worth.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('computeCurrent sums accounts, assets, and debts per currency',
      () async {
    final AppDatabase db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final DriftNetWorthRepository repo =
        DriftNetWorthRepository(db, OutboxWriter(db), () {});

    final DateTime now = DateTime.utc(2026, 1, 1);
    const String userId = 'user-1';

    await db.into(db.financialAccounts).insert(
          FinancialAccountsCompanion.insert(
            id: 'acc-1',
            userId: userId,
            name: 'Cash',
            type: 'cash',
            currency: 'INR',
            openingBalance: const Value<double>(1000),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.transactions).insert(
          TransactionsCompanion.insert(
            id: 'txn-1',
            userId: userId,
            accountId: 'acc-1',
            kind: 'expense',
            amount: 200,
            currency: 'INR',
            occurredAt: now,
            clientUpdatedAt: now,
            serverUpdatedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.assets).insert(
          AssetsCompanion.insert(
            id: 'asset-1',
            userId: userId,
            name: 'Bike',
            value: 5000,
            currency: 'INR',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db.into(db.debts).insert(
          DebtsCompanion.insert(
            id: 'debt-1',
            userId: userId,
            name: 'Loan',
            principal: 1000,
            currentBalance: 300,
            currency: 'INR',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final Map<String, NetWorthEntry> result =
        await repo.computeCurrent(userId);

    expect(result.keys, <String>['INR']);
    // 800 account balance (1000 opening − 200 expense) + 5000 asset.
    expect(result['INR']!.assets, 5800);
    expect(result['INR']!.liabilities, 300);
  });
}
