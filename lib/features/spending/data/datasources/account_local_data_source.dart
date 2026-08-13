import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';

/// The account every transaction hangs off.
///
/// Extracted because both manual entry and recurring-income generation need
/// it, and duplicating "find or create the default account" is how two
/// accounts called Cash appear.
class AccountLocalDataSource {
  const AccountLocalDataSource(this._db);

  final AppDatabase _db;

  /// Name given to the account created on first use.
  static const defaultAccountName = 'Cash';

  /// Currency assumed until accounts are something the user manages.
  static const defaultCurrency = 'USD';

  /// Finds the ledger's default account, creating it the first time.
  ///
  /// Every transaction needs an account, but the app has no account UI yet.
  /// Rather than make the column nullable — which would weaken the Postgres
  /// schema for a temporary gap in the UI — one is created on demand.
  ///
  /// Looked up by ledger rather than by owner, so both partners in a family
  /// account book against the same row. Scoping it by owner would give a shared
  /// book two accounts called Cash, one per person, and every join through
  /// `account_id` would then depend on who happened to record the entry.
  Future<String> defaultAccountId({
    required String ownerId,
    required String ledgerId,
  }) async {
    final existing =
        await (_db.select(_db.accounts)
              ..where(
                (row) =>
                    row.ledgerId.equals(ledgerId) &
                    row.name.equals(defaultAccountName) &
                    row.deletedAt.isNull(),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) return existing.id;

    final created = await _db
        .into(_db.accounts)
        .insertReturning(
          AccountsCompanion.insert(
            // Whoever books the first entry is recorded as having made the
            // account; either partner may use it.
            ownerId: ownerId,
            ledgerId: Value(ledgerId),
            name: defaultAccountName,
            currency: defaultCurrency,
          ),
        );

    return created.id;
  }
}
