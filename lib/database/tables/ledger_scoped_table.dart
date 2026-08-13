import 'package:drift/drift.dart';
import 'package:my_pnl/database/tables/ledgers.dart';

/// Columns shared by every table whose rows live inside a ledger.
///
/// The two say different things, and the difference is the whole of how a
/// family account works:
///
/// * [ledgerId] is *who can see the row*. Reads filter on it, the sync rules
///   bucket on it, and the Postgres policies admit it to anyone who is a member
///   of that ledger. Both partners' rows carry the same one, which is what makes
///   their spending add up to a single total.
/// * [ownerId] is *who wrote the row*. Nothing reads by it any more, but it is
///   what labels an entry with its author, and what the policy on
///   `transactions` checks so that one partner cannot rewrite the other's
///   history.
mixin LedgerScopedTable on Table {
  /// Who wrote the row. Must be the signed-in user: the Postgres policies
  /// check it on every insert.
  TextColumn get ownerId => text()();

  /// References [Ledgers.id] — which book the row belongs to.
  ///
  /// Nullable only because rows written before ledgers existed sync down
  /// without it, exactly as `categories.kind` did when it was added. The
  /// startup repair pass stamps those with their owner's personal ledger, and
  /// reads skip a row until it has one; nothing in the app inserts without it.
  TextColumn get ledgerId => text().nullable()();
}
