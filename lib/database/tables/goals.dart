import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// How much the user is trying to save up.
///
/// One live row per owner: the goal is a single figure the whole app talks
/// about, so saving a new one edits the row rather than adding a second. A
/// table rather than a preference because it has to sync like everything else,
/// and because a tombstoned row is how "the goal was cleared" travels.
@DataClassName('GoalRow')
class Goals extends Table with SyncedTable {
  /// Owner of the row. Sync rules bucket on this, and the matching Postgres
  /// RLS policy checks it, so it must be set on every insert.
  TextColumn get ownerId => text()();

  /// The figure being saved towards, scaled by `amountScale`. Always positive.
  IntColumn get targetAmountScaled => integer()();
}
