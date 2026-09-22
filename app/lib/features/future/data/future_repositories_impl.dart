import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../domain/entities/future_entities.dart';
import '../domain/repositories/future_repositories.dart';

/// Repository pattern used by every feature: reads are reactive Drift
/// queries (the UI's source of truth), writes run one local transaction
/// that (1) updates the entity row marked dirty and (2) enqueues the wire
/// payload in the outbox — the sync engine takes it from there. Soft
/// deletes only.
class DriftLifeAreaRepository implements LifeAreaRepository {
  DriftLifeAreaRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;

  /// Called after every committed write — wired to SyncEngine.kick().
  final void Function() _onWrite;

  @override
  Stream<List<LifeArea>> watchAll() {
    return (_db.select(_db.lifeAreas)
          ..where((db.$LifeAreasTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$LifeAreasTable)>[
            (db.$LifeAreasTable t) => OrderingTerm.asc(t.sortOrder),
          ]))
        .watch()
        .map(
          (List<db.LifeArea> rows) =>
              rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<LifeArea?> getById(String id) async {
    final db.LifeArea? row = await (_db.select(_db.lifeAreas)
          ..where((db.$LifeAreasTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(LifeArea lifeArea) => _write(lifeArea, 'insert');

  @override
  Future<void> update(LifeArea lifeArea) => _write(lifeArea, 'update');

  @override
  Future<void> delete(String id) async {
    final LifeArea? existing = await getById(id);
    if (existing == null) return;
    await _write(
      existing.copyWith(deletedAt: DateTime.now().toUtc()),
      'update',
    );
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    for (int i = 0; i < orderedIds.length; i++) {
      final LifeArea? area = await getById(orderedIds[i]);
      if (area != null && area.sortOrder != i) {
        await _write(
          area.copyWith(sortOrder: i, updatedAt: DateTime.now().toUtc()),
          'update',
        );
      }
    }
  }

  Future<void> _write(LifeArea area, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.lifeAreas).insertOnConflictUpdate(
            db.LifeAreasCompanion.insert(
              id: area.id,
              userId: area.userId,
              name: area.name,
              color: Value<String?>(area.color),
              icon: Value<String?>(area.icon),
              sortOrder: Value<int>(area.sortOrder),
              createdAt: area.createdAt,
              updatedAt: area.updatedAt,
              deletedAt: Value<DateTime?>(area.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'life_areas',
        entityId: area.id,
        operation: operation,
        payload: _toWire(area),
      );
    });
    _onWrite();
  }

  static LifeArea _toEntity(db.LifeArea row) {
    return LifeArea(
      id: row.id,
      userId: row.userId,
      name: row.name,
      color: row.color,
      icon: row.icon,
      sortOrder: row.sortOrder,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }

  static Map<String, dynamic> _toWire(LifeArea area) {
    return <String, dynamic>{
      'id': area.id,
      'user_id': area.userId,
      'name': area.name,
      'color': area.color,
      'icon': area.icon,
      'sort_order': area.sortOrder,
      'created_at': WireCodec.toWireTimestamp(area.createdAt),
      'updated_at': WireCodec.toWireTimestamp(area.updatedAt),
      'deleted_at': area.deletedAt == null
          ? null
          : WireCodec.toWireTimestamp(area.deletedAt!),
    };
  }
}

class DriftVisionRepository implements VisionRepository {
  DriftVisionRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  @override
  Stream<List<Vision>> watchAll() {
    return (_db.select(_db.visions)
          ..where((db.$VisionsTable t) => t.deletedAt.isNull())
          ..orderBy(<OrderingTerm Function(db.$VisionsTable)>[
            (db.$VisionsTable t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch()
        .map(
          (List<db.Vision> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Stream<List<Vision>> watchByLifeArea(String lifeAreaId) {
    return (_db.select(_db.visions)
          ..where(
            (db.$VisionsTable t) =>
                t.deletedAt.isNull() & t.lifeAreaId.equals(lifeAreaId),
          ))
        .watch()
        .map(
          (List<db.Vision> rows) => rows.map(_toEntity).toList(growable: false),
        );
  }

  @override
  Future<Vision?> getById(String id) async {
    final db.Vision? row = await (_db.select(_db.visions)
          ..where((db.$VisionsTable t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> create(Vision vision) => _write(vision, 'insert');

  @override
  Future<void> update(Vision vision) => _write(vision, 'update');

  @override
  Future<void> delete(String id) async {
    final Vision? existing = await getById(id);
    if (existing == null) return;
    await _write(existing.copyWith(deletedAt: DateTime.now().toUtc()), 'update');
  }

  Future<void> _write(Vision vision, String operation) async {
    await _db.transaction(() async {
      await _db.into(_db.visions).insertOnConflictUpdate(
            db.VisionsCompanion.insert(
              id: vision.id,
              userId: vision.userId,
              lifeAreaId: Value<String?>(vision.lifeAreaId),
              title: vision.title,
              description: Value<String?>(vision.description),
              horizonYears: Value<int?>(vision.horizonYears),
              createdAt: vision.createdAt,
              updatedAt: vision.updatedAt,
              deletedAt: Value<DateTime?>(vision.deletedAt),
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'visions',
        entityId: vision.id,
        operation: operation,
        payload: <String, dynamic>{
          'id': vision.id,
          'user_id': vision.userId,
          'life_area_id': vision.lifeAreaId,
          'title': vision.title,
          'description': vision.description,
          'horizon_years': vision.horizonYears,
          'created_at': WireCodec.toWireTimestamp(vision.createdAt),
          'updated_at': WireCodec.toWireTimestamp(vision.updatedAt),
          'deleted_at': vision.deletedAt == null
              ? null
              : WireCodec.toWireTimestamp(vision.deletedAt!),
        },
      );
    });
    _onWrite();
  }

  static Vision _toEntity(db.Vision row) {
    return Vision(
      id: row.id,
      userId: row.userId,
      lifeAreaId: row.lifeAreaId,
      title: row.title,
      description: row.description,
      horizonYears: row.horizonYears,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      deletedAt: row.deletedAt,
    );
  }
}
