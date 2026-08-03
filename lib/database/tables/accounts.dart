import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// A brokerage, exchange or cash account that transactions belong to.
@DataClassName('AccountRow')
class Accounts extends Table with SyncedTable {
  /// Owner of the row. Sync rules bucket on this, and the matching Postgres
  /// RLS policy checks it, so it must be set on every insert.
  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  /// ISO 4217 code, e.g. `USD`. Determines the minor unit of every cash
  /// amount recorded against this account.
  TextColumn get currency => text()();
}
