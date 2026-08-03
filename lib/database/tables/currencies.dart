import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// A currency the user defined, on top of the app's base currency.
@DataClassName('CurrencyRow')
class Currencies extends Table with SyncedTable {
  /// Owner of the row. Sync rules bucket on this, and the matching Postgres
  /// RLS policy checks it, so it must be set on every insert.
  TextColumn get ownerId => text()();

  /// Short code, e.g. `EUR` or `BTC`. Unique per owner — enforced in Postgres,
  /// since the local PowerSync views carry no constraints.
  TextColumn get ticker => text()();

  /// Optional symbol or glyph shown instead of the ticker, e.g. `€`.
  TextColumn get icon => text().nullable()();

  /// What one unit is worth in the base currency, scaled by `rateScale`.
  IntColumn get exchangeRateScaled => integer()();
}
