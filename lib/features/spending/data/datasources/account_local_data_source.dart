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

  /// Finds the owner's default account, creating it the first time.
  ///
  /// Every transaction needs an account, but the app has no account UI yet.
  /// Rather than make the column nullable — which would weaken the Postgres
  /// schema for a temporary gap in the UI — one is created on demand.
  Future<String> defaultAccountId(String ownerId) async {
    final existing =
        await (_db.select(_db.accounts)
              ..where(
                (row) =>
                    row.ownerId.equals(ownerId) &
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
            ownerId: ownerId,
            name: defaultAccountName,
            currency: defaultCurrency,
          ),
        );

    return created.id;
  }
}
