import 'package:app/data/local/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('insert, query, and watch a LifeArea round-trips correctly', () async {
    final DateTime now = DateTime.utc(2026, 1, 1);

    await db
        .into(db.lifeAreas)
        .insert(
          LifeAreasCompanion.insert(
            id: 'la-1',
            userId: 'user-1',
            name: 'Health',
            createdAt: now,
            updatedAt: now,
          ),
        );

    final List<LifeArea> rows = await db.select(db.lifeAreas).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Health');
    expect(rows.single.isDirty, isFalse);

    final Stream<List<LifeArea>> stream = db.select(db.lifeAreas).watch();
    expect(stream, emits(hasLength(1)));

    await (db.update(db.lifeAreas)
          ..where((t) => t.id.equals('la-1')))
        .write(const LifeAreasCompanion(isDirty: Value(true)));

    final LifeArea updated = await (db.select(db.lifeAreas)
          ..where((t) => t.id.equals('la-1')))
        .getSingle();
    expect(updated.isDirty, isTrue);
  });

  test('outbox rows can be inserted and drained', () async {
    final DateTime now = DateTime.utc(2026, 1, 1);

    await db
        .into(db.syncOutbox)
        .insert(
          SyncOutboxCompanion.insert(
            entityTable: 'life_areas',
            entityId: 'la-1',
            operation: 'insert',
            payload: '{"id":"la-1"}',
            createdAt: now,
          ),
        );

    final List<SyncOutboxData> pending = await db.select(db.syncOutbox).get();
    expect(pending, hasLength(1));
    expect(pending.single.status, 'pending');

    await db.delete(db.syncOutbox).go();
    expect(await db.select(db.syncOutbox).get(), isEmpty);
  });
}
