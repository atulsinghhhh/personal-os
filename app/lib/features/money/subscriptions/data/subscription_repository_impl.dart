import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../../../../shared/models/money.dart';
import '../domain/entities/subscription.dart';
import '../domain/repositories/subscription_repository.dart';

String billingCycleToWire(BillingCycle cycle) => switch (cycle) {
      BillingCycle.weekly => 'weekly',
      BillingCycle.monthly => 'monthly',
      BillingCycle.yearly => 'yearly',
    };

BillingCycle billingCycleFromWire(String value) => switch (value) {
      'weekly' => BillingCycle.weekly,
      'yearly' => BillingCycle.yearly,
      _ => BillingCycle.monthly,
    };

class DriftSubscriptionRepository implements SubscriptionRepository {
  DriftSubscriptionRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Subscription>> watchAll({bool activeOnly = false}) {
    final SimpleSelectStatement<db.$SubscriptionsTable, db.Subscription>
        query = _db.select(_db.subscriptions)
          ..where((db.$SubscriptionsTable t) => t.deletedAt.isNull());
    if (activeOnly) {
      query.where((db.$SubscriptionsTable t) => t.isActive.equals(true));
    }
    query.orderBy(<OrderingTerm Function(db.$SubscriptionsTable)>[
      (db.$SubscriptionsTable t) => OrderingTerm.asc(t.service),
    ]);
    return query.watch().map(
          (List<db.Subscription> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Subscription?> getById(String id) async {
    final db.Subscription? row = await (_db.select(_db.subscriptions)
          ..where((db.$SubscriptionsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Subscription subscription) =>
      _write(subscription, 'insert');

  @override
  Future<void> update(Subscription subscription) =>
      _write(subscription, 'update');

  @override
  Future<void> delete(String id) async {
    final Subscription? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(Subscription s, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.subscriptions).insertOnConflictUpdate(
            db.SubscriptionsCompanion.insert(
              id: s.id,
              userId: s.userId,
              service: s.service,
              amount: s.amount.amount,
              currency: s.amount.currency,
              billingCycle:
                  Value<String>(billingCycleToWire(s.billingCycle)),
              renewalDate: Value<DateTime?>(s.renewalDate),
              categoryId: Value<String?>(s.categoryId),
              accountId: Value<String?>(s.accountId),
              cancellationNote: Value<String?>(s.cancellationNote),
              isActive: Value<bool>(s.isActive),
              createdAt: s.createdAt,
              updatedAt: s.updatedAt,
              deletedAt: Value<DateTime?>(s.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'subscriptions',
        entityId: s.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': s.id,
          'user_id': s.userId,
          'service': s.service,
          'amount': s.amount.amount,
          'currency': s.amount.currency,
          'billing_cycle': billingCycleToWire(s.billingCycle),
          'renewal_date':
              s.renewalDate?.toIso8601String().substring(0, 10),
          'category_id': s.categoryId,
          'account_id': s.accountId,
          'cancellation_note': s.cancellationNote,
          'is_active': s.isActive,
          'created_at': WireCodec.toWireTimestamp(s.createdAt),
          'updated_at': WireCodec.toWireTimestamp(s.updatedAt),
          'deleted_at': s.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(s.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Subscription _toEntity(db.Subscription row) {
    return Subscription(
      id: row.id,
      userId: row.userId,
      service: row.service,
      amount: Money(amount: row.amount, currency: row.currency),
      billingCycle: billingCycleFromWire(row.billingCycle),
      renewalDate: row.renewalDate,
      categoryId: row.categoryId,
      accountId: row.accountId,
      cancellationNote: row.cancellationNote,
      isActive: row.isActive,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
