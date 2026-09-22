import 'package:drift/drift.dart';

import '../../../core/sync/outbox/outbox_writer.dart';
import '../../../core/sync/wire_codec.dart';
import '../../../data/local/database.dart' as db;
import '../../../shared/models/profile.dart';

/// Local-first profile access. The row is created server-side by the
/// handle_new_user trigger and pulled on first sync; writes go through the
/// same dirty-flag + outbox path as everything else.
class ProfileRepository {
  ProfileRepository(this._db, this._outbox, this._onWrite);

  final db.AppDatabase _db;
  final OutboxWriter _outbox;
  final void Function() _onWrite;

  Stream<Profile?> watch(String userId) {
    return (_db.select(_db.profiles)
          ..where((db.$ProfilesTable t) => t.id.equals(userId)))
        .watch()
        .map(
          (List<db.Profile> rows) =>
              rows.isEmpty ? null : _toEntity(rows.single),
        );
  }

  Future<Profile?> get(String userId) async {
    final db.Profile? row = await (_db.select(_db.profiles)
          ..where((db.$ProfilesTable t) => t.id.equals(userId)))
        .getSingleOrNull();
    return row == null ? null : _toEntity(row);
  }

  Future<void> save(Profile profile) async {
    await _db.transaction(() async {
      await _db.into(_db.profiles).insertOnConflictUpdate(
            db.ProfilesCompanion.insert(
              id: profile.id,
              displayName: Value<String?>(profile.displayName),
              defaultCurrency: Value<String?>(profile.defaultCurrency),
              onboardingCompletedAt:
                  Value<DateTime?>(profile.onboardingCompletedAt),
              createdAt: profile.createdAt,
              updatedAt: profile.updatedAt,
              isDirty: const Value<bool>(true),
              localUpdatedAt: Value<DateTime?>(DateTime.now().toUtc()),
            ),
          );
      await _outbox.enqueue(
        entityTable: 'profiles',
        entityId: profile.id,
        operation: 'update',
        payload: <String, dynamic>{
          'id': profile.id,
          'display_name': profile.displayName,
          'default_currency': profile.defaultCurrency,
          'onboarding_completed_at': profile.onboardingCompletedAt == null
              ? null
              : WireCodec.toWireTimestamp(profile.onboardingCompletedAt!),
          'created_at': WireCodec.toWireTimestamp(profile.createdAt),
          'updated_at': WireCodec.toWireTimestamp(profile.updatedAt),
        },
      );
    });
    _onWrite();
  }

  static Profile _toEntity(db.Profile row) {
    return Profile(
      id: row.id,
      displayName: row.displayName,
      defaultCurrency: row.defaultCurrency,
      onboardingCompletedAt: row.onboardingCompletedAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}
