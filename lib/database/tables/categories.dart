import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// A user-defined bucket that transactions are grouped by for reporting.
@DataClassName('CategoryRow')
class Categories extends Table with SyncedTable {
  /// Owner of the row. Sync rules bucket on this, and the matching Postgres
  /// RLS policy checks it, so it must be set on every insert.
  TextColumn get ownerId => text()();

  TextColumn get name => text()();

  /// Packed ARGB, as `Color.toARGB32()` produces.
  IntColumn get colorArgb => integer()();

  /// Key into the app's icon catalogue rather than a Flutter code point.
  ///
  /// Storing code points would defeat icon tree-shaking and tie rows to a
  /// particular Flutter version's font.
  TextColumn get iconKey => text()();

  /// `expense` or `income`.
  ///
  /// Nullable because rows created before this column existed sync down
  /// without it; the mapper reads null as expense, which is all the app
  /// tracked at the time.
  TextColumn get kind => text().nullable()();

  /// Note copied onto transactions booked against this category.
  TextColumn get description => text().nullable()();

  /// Day of the month a recurring income lands on, 1–31.
  ///
  /// Set together with [recurringAmountScaled] or not at all: both null means
  /// the category does not recur.
  IntColumn get recurringDayOfMonth => integer().nullable()();

  /// Amount generated on each occurrence, scaled by `amountScale`.
  IntColumn get recurringAmountScaled => integer().nullable()();
}
