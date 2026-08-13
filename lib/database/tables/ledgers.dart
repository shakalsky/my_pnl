import 'package:drift/drift.dart';
import 'package:my_pnl/database/ids.dart';
import 'package:my_pnl/database/tables/synced_table.dart';

/// A book of records: everything below it is one set of categories, one set of
/// transactions, one goal.
///
/// Every other table in the app carries a `ledger_id` saying which book its row
/// belongs to, and reads filter on it. That is what makes a family account
/// possible — two people writing into the same book see one set of totals,
/// while their own books stay separate.
///
/// Not the same thing as an owner. [ownerId] is who created the ledger, which
/// only decides who may rename it; who may *read* it is [LedgerMembers].
@DataClassName('LedgerRow')
class Ledgers extends Table with SyncedTable {
  /// Who created it. Sync rules do not bucket on this — see [LedgerMembers] —
  /// but the RLS policy checks it on a rename.
  TextColumn get ownerId => text()();

  /// What the switcher shows. `Personal` on the book created for a new user.
  TextColumn get name => text()();

  /// `personal` or `family`. Stored as plain text rather than an enum column so
  /// a value from a newer build syncing down cannot fail to parse — the same
  /// reason `categories.kind` is stored the way it is.
  ///
  /// The distinction is not about permissions — a family ledger with one member
  /// behaves exactly like a personal one — but about what the app offers to do
  /// with it: only a family ledger can be shared or left.
  TextColumn get kind => text()();

  /// The code a partner types to join, upper-case and short enough to read out
  /// loud.
  ///
  /// Null on a personal ledger, which nobody else can join. Rotating it revokes
  /// every invite that has not been used yet, which is the only way to take an
  /// invite back.
  TextColumn get inviteCode => text().nullable()();
}

/// Who may read a ledger.
///
/// Sync rules bucket on this table: a device receives exactly the ledgers its
/// user has a row here for, and every row in those ledgers. The matching
/// Postgres policies read it through a `security definer` function, because a
/// policy on this table that queried this table would recurse.
///
/// One row per (ledger, user), at an id derived from that pair rather than a
/// random one, so two devices adding the same person cannot produce two rows.
@DataClassName('LedgerMemberRow')
class LedgerMembers extends Table with SyncedTable {
  /// References [Ledgers.id].
  TextColumn get ledgerId => text()();

  /// The auth user this membership admits. Matched against `request.user_id()`
  /// in the sync rules and `auth.uid()` in the policies.
  TextColumn get userId => text()();

  /// What to call this member beside their entries.
  ///
  /// Written by the member's own device from their sign-in email, because
  /// `auth.users` is not readable by clients — a partner's name has to travel
  /// as ordinary synced data or not at all. Null until their device has
  /// written it.
  TextColumn get displayName => text().nullable()();

  /// `owner` or `member`, stored as text for the same reason as [Ledgers.kind].
  TextColumn get role => text()();
}

/// The id of a user's own book.
///
/// Derived from the user id rather than random, so every device that user signs
/// in on works out the same id for it. Two phones that both open the app before
/// either has synced then write the same row, instead of two personal ledgers
/// that can never be merged.
String personalLedgerId(String userId) => derivedId('ledger:personal:$userId');

/// The id of a membership row.
///
/// Derived for the same reason as [personalLedgerId]: joining twice, or from
/// two devices at once, has to come to one row.
String ledgerMemberId({required String ledgerId, required String userId}) =>
    derivedId('ledger-member:$ledgerId:$userId');
