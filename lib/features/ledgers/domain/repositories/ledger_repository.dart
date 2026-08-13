import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';

/// Raised when something about a ledger cannot be done for a reason worth
/// showing the reader — a code that matches nothing, a family account there is
/// no session to join.
class LedgerFailure implements Exception {
  const LedgerFailure(this.message);

  final String message;

  @override
  String toString() => 'LedgerFailure: $message';
}

/// Which books the reader has, and which one the app is looking at.
///
/// The one repository the others depend on: every read below this line is
/// narrowed to `activeId`, so nothing else in the app has to know that more than
/// one ledger exists.
abstract interface class LedgerRepository {
  /// Every ledger the signed-in user is a member of, with its members, newest
  /// last and the personal one first.
  ///
  /// Re-emitted as memberships arrive: a family account joined on another
  /// device shows up here when sync catches up, without anything asking again.
  Stream<List<Ledger>> watchLedgers();

  /// The active ledger's id, synchronously. What the other repositories stamp
  /// on writes and filter reads by.
  String get activeId;

  /// Makes the app ready to read: gives the user a personal ledger if they have
  /// none, then settles which ledger to open.
  ///
  /// Returns the id it settled on. Called before the first frame, because a page
  /// that queried first would read from whatever ledger the last session left
  /// behind.
  ///
  /// Falls back to the personal ledger when the remembered one is not one of the
  /// user's — which is the case on a device someone else has signed into. It
  /// does not forget the remembered choice while doing so: on a cold start the
  /// membership rows may simply not have synced yet, and discarding the choice
  /// then would move a reader out of their family account for good.
  Future<String> resolveActive();

  /// Switches which ledger the app reads and writes.
  ///
  /// Throws [LedgerFailure] if the user is not a member of it — writing there
  /// would produce rows the server refuses.
  Future<void> select(String ledgerId);

  /// Creates another book of the reader's own.
  ///
  /// The first one is made for them by [resolveActive] and always exists; this is
  /// for the ones after it. Throws [LedgerFailure] once they have
  /// [LedgerLimits.personal].
  Future<Ledger> createPersonalLedger(String name);

  /// Creates a family account, with the creator as its first member, and an
  /// invite code to hand to a partner.
  ///
  /// Throws [LedgerFailure] if the reader is already in one — see
  /// [LedgerLimits.family]. Leaving the one they are in is what frees the slot,
  /// whether they created it or joined it.
  Future<Ledger> createFamilyLedger(String name);

  /// Joins the family account with this code.
  ///
  /// The one operation here that needs the network: sync only ever delivers
  /// ledgers you are already in, so there is nothing on the device to match a
  /// code against. Throws [LedgerFailure] when there is no session, no
  /// connection, or no ledger with that code.
  Future<Ledger> joinFamilyLedger(String code);

  /// Replaces a family account's invite code, which revokes every invite that
  /// has not been used.
  ///
  /// Throws [LedgerFailure] unless the caller created the ledger.
  Future<String> rotateInviteCode(String ledgerId);

  /// Gives up access to a family account.
  ///
  /// The entries the leaver recorded stay in the ledger — they are part of a
  /// shared history that the other member is still reading, and removing them
  /// would silently change totals that person has already seen. What goes is
  /// the access.
  ///
  /// Throws [LedgerFailure] for a personal ledger, which is nobody's to leave —
  /// see [deletePersonalLedger] for those.
  ///
  /// Leaving as the last member tombstones the ledger as well. A book nobody is
  /// in is one nobody can ever open again, and leaving its invite code live would
  /// let a partner join something empty.
  Future<void> leave(String ledgerId);

  /// Discards one of the reader's own books.
  ///
  /// A tombstone on the ledger rather than a sweep through its rows: they stay
  /// where they are, unreachable because every read starts by narrowing to a
  /// ledger. That is what makes this recoverable by hand if it was a mistake, and
  /// it is why the sheet asks first.
  ///
  /// Throws [LedgerFailure] for a family account — that is [leave] — and for the
  /// reader's first personal book, which the app relies on always being there.
  Future<void> deletePersonalLedger(String ledgerId);

  /// Stamps rows written before ledgers existed with their owner's personal
  /// ledger, and returns how many it changed.
  ///
  /// Idempotent, and the reason `ledger_id` is nullable on the client. Runs at
  /// startup: until a row has a ledger, no read returns it.
  Future<int> adoptUnscopedRows();
}
