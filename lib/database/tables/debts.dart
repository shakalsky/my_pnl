import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// Money owed, in either direction.
///
/// Deliberately not a transactions row: a debt is a promise, not a movement
/// of money. Booking one into the ledger would count the same cash twice —
/// once when it was lent and again when it came back — so debts are tracked
/// beside the ledger and never touch the spending totals.
@DataClassName('DebtRow')
class Debts extends Table with SyncedTable {
  /// Owner of the row. Sync rules bucket on this, and the matching Postgres
  /// RLS policy checks it, so it must be set on every insert.
  TextColumn get ownerId => text()();

  /// The person or company on the other side of the debt.
  TextColumn get counterparty => text()();

  /// `owed_to_me` or `owed_by_me`. See `DebtDirection` in the domain layer,
  /// which owns the mapping.
  TextColumn get direction => text()();

  /// Magnitude, scaled by `amountScale`, always positive — which way the money
  /// points is [direction]'s job. Storing a sign here as well would give two
  /// sources of truth that could disagree.
  IntColumn get amountScaled => integer()();

  /// What the debt is for. Optional.
  TextColumn get note => text().nullable()();

  /// When repayment is expected. Null means no agreed date.
  TextColumn get dueAt => text().map(const UtcDateTimeConverter()).nullable()();

  /// When the debt was squared up. Null means it is still open.
  ///
  /// A timestamp rather than a flag: "settled" is the interesting date to keep,
  /// and a boolean would answer strictly less.
  TextColumn get settledAt =>
      text().map(const UtcDateTimeConverter()).nullable()();
}
