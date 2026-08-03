import 'package:drift/drift.dart';
import 'package:my_pnl/database/ids.dart';

/// Stores a [DateTime] as an ISO-8601 string, always in UTC.
///
/// PowerSync's local columns are text/integer/real only, so timestamps travel
/// as strings. Forcing UTC here rather than trusting callers means the value
/// is always `...Z` — a local `DateTime` would serialize with a `+03:00` style
/// offset, which sorts wrong in SQLite and drifts as the device moves.
class UtcDateTimeConverter extends TypeConverter<DateTime, String> {
  const UtcDateTimeConverter();

  @override
  DateTime fromSql(String fromDb) => DateTime.parse(fromDb).toUtc();

  @override
  String toSql(DateTime value) => value.toUtc().toIso8601String();
}

/// The current time as this database stores it.
String nowIso() => DateTime.now().toUtc().toIso8601String();

/// Columns shared by every table that can be synced to a backend.
///
/// Deletes are soft: a hard delete is invisible to sync, because a peer cannot
/// tell "row was deleted" from "row has not arrived yet". Set [deletedAt]
/// instead and filter it out on read. Ids are never reused.
mixin SyncedTable on Table {
  TextColumn get id => text().clientDefault(newId)();

  TextColumn get createdAt =>
      text().map(const UtcDateTimeConverter()).clientDefault(nowIso)();

  TextColumn get updatedAt =>
      text().map(const UtcDateTimeConverter()).clientDefault(nowIso)();

  TextColumn get deletedAt =>
      text().map(const UtcDateTimeConverter()).nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
