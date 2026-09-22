import 'package:drift/drift.dart';

/// Conversions between the Supabase wire format (snake_case JSON, ISO 8601
/// timestamps) and Drift rows. The outbox stores payloads in wire format so
/// pushing is a straight pass-through; pulls run server rows through
/// [wireToInsertable] to apply them locally without per-table mapping code.
abstract final class WireCodec {
  /// Local-only sync-machinery columns that must never leave the device.
  static const Set<String> localOnlyColumns = <String>{
    'is_dirty',
    'local_updated_at',
  };

  /// Builds a Drift [Insertable] for [table] from a wire JSON map. Unknown
  /// wire keys are ignored; local-only columns are excluded so pulls always
  /// land rows as clean (is_dirty defaults false on insert, and the engine
  /// clears it explicitly on update).
  static Insertable<dynamic> wireToInsertable(
    TableInfo<Table, dynamic> table,
    Map<String, dynamic> wire, {
    bool markClean = false,
  }) {
    final Map<String, Expression<Object>> values =
        <String, Expression<Object>>{};

    for (final GeneratedColumn<Object> column in table.$columns) {
      final String name = column.name;
      if (localOnlyColumns.contains(name)) continue;
      if (!wire.containsKey(name)) continue;

      final dynamic raw = wire[name];
      if (raw == null) {
        values[name] = const Constant<String>(null);
        continue;
      }

      switch (column.type) {
        case DriftSqlType.dateTime:
          values[name] = Variable<DateTime>(
            raw is DateTime ? raw.toUtc() : DateTime.parse(raw as String).toUtc(),
          );
        case DriftSqlType.bool:
          values[name] = Variable<bool>(raw as bool);
        case DriftSqlType.int:
        case DriftSqlType.bigInt:
          values[name] = Variable<int>((raw as num).toInt());
        case DriftSqlType.double:
          values[name] = Variable<double>((raw as num).toDouble());
        default:
          values[name] = Variable<String>(raw.toString());
      }
    }

    if (markClean) {
      values['is_dirty'] = const Constant<bool>(false);
    }

    // Never is a subtype of every row type, so this satisfies the runtime
    // Insertable<D> covariance check for any table.
    return RawValuesInsertable<Never>(values);
  }

  /// ISO 8601 UTC string for wire payloads.
  static String toWireTimestamp(DateTime value) =>
      value.toUtc().toIso8601String();
}
