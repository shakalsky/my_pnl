import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/ledger_scoped_table.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// A user-defined bucket that transactions are grouped by for reporting.
///
/// Shared within a ledger: in a family account both partners record against the
/// same categories, which is what lets one grid of tiles add up to one total.
/// Either member may edit them — unlike the entries booked against them.
@DataClassName('CategoryRow')
class Categories extends Table with SyncedTable, LedgerScopedTable {
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

  /// Day of the month a recurring income lands on, 1–31.
  ///
  /// Set together with [recurringAmountScaled] or not at all: both null means
  /// the category does not recur.
  IntColumn get recurringDayOfMonth => integer().nullable()();

  /// Amount generated on each occurrence, scaled by `amountScale`.
  IntColumn get recurringAmountScaled => integer().nullable()();

  /// Where the category sits in the grid, low first.
  ///
  /// Nullable, and null means "not arranged": rows written before this column
  /// existed, and every category created since the last drag, have no value.
  /// Reads sort those after the arranged ones by age, so a new category lands
  /// at the end of the grid rather than at the front.
  IntColumn get sortOrder => integer().nullable()();
}
