import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/ledger_scoped_table.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// How much the user is trying to save up.
///
/// One live row per ledger: the goal is a single figure the whole app talks
/// about, so saving a new one edits the row rather than adding a second. In a
/// family account that makes it one goal the household is saving towards, which
/// is the only reading that agrees with the shared total it is measured against.
/// A table rather than a preference because it has to sync like everything else,
/// and because a tombstoned row is how "the goal was cleared" travels.
@DataClassName('GoalRow')
class Goals extends Table with SyncedTable, LedgerScopedTable {
  /// The figure being saved towards, scaled by `amountScale`. Always positive.
  IntColumn get targetAmountScaled => integer()();
}
