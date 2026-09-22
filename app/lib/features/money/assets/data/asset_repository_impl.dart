import 'package:drift/drift.dart';

import '../../../../core/sync/outbox/outbox_writer.dart';
import '../../../../core/sync/wire_codec.dart';
import '../../../../data/local/database.dart' as db;
import '../domain/entities/asset.dart';
import '../domain/repositories/asset_repository.dart';

class DriftAssetRepository implements AssetRepository {
  DriftAssetRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Asset>> watchAll() {
    return (_db.select(_db.assets)
          ..where((db.$AssetsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$AssetsTable)>[
            (db.$AssetsTable t) => OrderingTerm.desc(t.value),
          ]))
        .watch()
        .map(
          (List<db.Asset> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Asset?> getById(String id) async {
    final db.Asset? row = await (_db.select(_db.assets)
          ..where((db.$AssetsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Asset asset) => _write(asset, 'insert');

  @override
  Future<void> update(Asset asset) => _write(asset, 'update');

  @override
  Future<void> delete(String id) async {
    final Asset? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  Future<void> _write(Asset asset, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.assets).insertOnConflictUpdate(
            db.AssetsCompanion.insert(
              id: asset.id,
              userId: asset.userId,
              name: asset.name,
              value: asset.value,
              currency: asset.currency,
              note: Value<String?>(asset.note),
              createdAt: asset.createdAt,
              updatedAt: asset.updatedAt,
              deletedAt: Value<DateTime?>(asset.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'assets',
        entityId: asset.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': asset.id,
          'user_id': asset.userId,
          'name': asset.name,
          'value': asset.value,
          'currency': asset.currency,
          'note': asset.note,
          'created_at': WireCodec.toWireTimestamp(asset.createdAt),
          'updated_at': WireCodec.toWireTimestamp(asset.updatedAt),
          'deleted_at': asset.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(asset.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Asset _toEntity(db.Asset row) {
    return Asset(
      id: row.id,
      userId: row.userId,
      name: row.name,
      value: row.value,
      currency: row.currency,
      note: row.note,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
