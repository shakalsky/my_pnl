import 'package:drift/drift.dart';
import 'package:drift_sqlite_async/drift_sqlite_async.dart';
// Used by the generated part file for the client-side defaults and converters.
import 'package:my_pnl/database/ids.dart';
import 'package:my_pnl/database/tables/accounts.dart';
import 'package:my_pnl/database/tables/categories.dart';
import 'package:my_pnl/database/tables/currencies.dart';
import 'package:my_pnl/database/tables/debts.dart';
import 'package:my_pnl/database/tables/goals.dart';
import 'package:my_pnl/database/tables/ledgers.dart';
import 'package:my_pnl/database/tables/synced_table.dart';
import 'package:my_pnl/database/tables/transactions.dart';
import 'package:sqlite_async/sqlite_async.dart';

export 'package:my_pnl/database/ids.dart';
export 'package:my_pnl/database/tables/accounts.dart';
export 'package:my_pnl/database/tables/categories.dart';
export 'package:my_pnl/database/tables/currencies.dart';
export 'package:my_pnl/database/tables/debts.dart';
export 'package:my_pnl/database/tables/goals.dart';
export 'package:my_pnl/database/tables/ledger_scoped_table.dart';
export 'package:my_pnl/database/tables/ledgers.dart';
export 'package:my_pnl/database/tables/synced_table.dart';
export 'package:my_pnl/database/tables/transactions.dart';

part 'database.g.dart';

/// Typed access to the local SQLite database.
///
/// In the app this runs on top of PowerSync's database: PowerSync owns the
/// file, creates the views drift queries, and replicates them. Drift's own
/// migrations are therefore disabled — schema changes arrive from the
/// PowerSync schema and the sync rules, not from `build_runner`.
@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Currencies,
    Debts,
    Goals,
    Ledgers,
    LedgerMembers,
    Transactions,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Opens drift over a PowerSync (or any `sqlite_async`) connection.
  AppDatabase(SqliteConnection connection)
    : _powerSyncManaged = true,
      super(SqliteAsyncDriftConnection(connection));

  /// Opens drift over a plain executor and lets drift create the tables.
  ///
  /// For unit tests only — use `NativeDatabase.memory()`. Nothing here syncs.
  // Positional, so the parameter name only exists to match the generated
  // superclass constructor and keep the analyzer quiet.
  AppDatabase.forTesting(super.e) : _powerSyncManaged = false;

  final bool _powerSyncManaged;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    if (!_powerSyncManaged) return MigrationStrategy();

    // The tables already exist as PowerSync views. Creating them here would
    // fail, and dropping them would destroy the sync state.
    return MigrationStrategy(onCreate: (m) async {});
  }
}
