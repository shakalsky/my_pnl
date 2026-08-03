import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/data/datasources/account_local_data_source.dart';
import 'package:my_pnl/features/spending/data/mappers/category_mapper.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Drift writes behind the transaction repository.
class TransactionLocalDataSource {
  const TransactionLocalDataSource(this._db);

  final AppDatabase _db;

  AccountLocalDataSource get _accounts => AccountLocalDataSource(_db);

  /// Name given to the account created on first use.
  static const String defaultAccountName =
      AccountLocalDataSource.defaultAccountName;

  /// Currency assumed until accounts are something the user manages.
  static const String defaultCurrency = AccountLocalDataSource.defaultCurrency;

  Future<void> recordSpend({
    required String ownerId,
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
  }) async {
    final accountId = await _accounts.defaultAccountId(ownerId);
    final signed = await _signFor(
      ownerId: ownerId,
      categoryId: categoryId,
      amountScaled: amountScaled,
    );

    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ownerId: ownerId,
            accountId: accountId,
            categoryId: Value(categoryId),
            side: TradeSide.buy,
            amountScaled: signed,
            currency: defaultCurrency,
            executedAt: occurredAt ?? DateTime.now().toUtc(),
          ),
        );
  }

  /// Every entry the owner has, newest first, with its category.
  ///
  /// A left join: an entry whose category was deleted with its entries kept
  /// still belongs in the ledger, and dropping it here would make the list
  /// disagree with the net total.
  Stream<List<LedgerEntry>> watchAllEntries(String ownerId) {
    final query =
        _db.select(_db.transactions).join([
          leftOuterJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId) &
                _db.categories.deletedAt.isNull(),
          ),
        ])
          ..where(
            _db.transactions.ownerId.equals(ownerId) &
                _db.transactions.deletedAt.isNull(),
          )
          ..orderBy([OrderingTerm.desc(_db.transactions.executedAt)])
          ..limit(allEntriesLimit);

    return query.watch().map(
      (rows) => rows.map((row) {
        final transaction = row.readTable(_db.transactions);

        return LedgerEntry(
          entry: SpendEntry(
            id: transaction.id,
            amountScaled: transaction.amountScaled,
            occurredAt: transaction.executedAt,
            note: transaction.note,
          ),
          category: row.readTableOrNull(_db.categories)?.toEntity(),
        );
      }).toList(),
    );
  }

  /// Income minus spending, across every category.
  ///
  /// A plain SUM: because income is stored positive and spending negative,
  /// the subtraction is already in the data.
  ///
  /// [month] narrows it to one UTC month, read the same way `watchMonthlyPnl`
  /// groups them, so the figure for a month agrees with that month's row there.
  /// Null sums the whole ledger.
  Stream<int> watchNetTotal(String ownerId, {CalendarMonth? month}) {
    final total = _db.transactions.amountScaled.sum();
    // See `watchMonthlyPnl` on the cast: the column is stored as text, and the
    // date functions read that text as it stands.
    final executedAt = _db.transactions.executedAt.dartCast<DateTime>();

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([total])
      ..where(
        _db.transactions.ownerId.equals(ownerId) &
            _db.transactions.deletedAt.isNull() &
            // `AND 1` when no month is asked for, which SQLite folds away.
            (month == null
                ? const Constant<bool>(true)
                : executedAt.year.equals(month.year) &
                      executedAt.month.equals(month.month)),
      );

    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Income minus spending per calendar month, newest first.
  ///
  /// Grouped in the database rather than in Dart: the ledger is unbounded, and
  /// pulling every row across to add it up would get slower every month.
  ///
  /// The month comes from `strftime` over the stored UTC timestamp, so months
  /// are UTC months. A device an hour either side of the boundary would
  /// otherwise move an entry between months just by travelling.
  Stream<List<MonthlyPnl>> watchMonthlyPnl(String ownerId) {
    // The column carries a type converter, so drift types it as the String it
    // is stored as. `dartCast` puts the DateTime back for the sake of the date
    // functions below and changes no SQL: `strftime` reads the ISO-8601 text
    // exactly as it stands.
    final executedAt = _db.transactions.executedAt.dartCast<DateTime>();
    final year = executedAt.year;
    final month = executedAt.month;
    final total = _db.transactions.amountScaled.sum();

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([year, month, total])
      ..where(
        _db.transactions.ownerId.equals(ownerId) &
            _db.transactions.deletedAt.isNull(),
      )
      ..groupBy([year, month])
      ..orderBy([OrderingTerm.desc(year), OrderingTerm.desc(month)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => MonthlyPnl(
              year: row.read(year)!,
              month: row.read(month)!,
              netScaled: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// Re-signs rows written before income and spending had signs.
  ///
  /// Idempotent, and only touches rows whose sign disagrees with their
  /// category — a spend stored positive, or income stored negative. Returns
  /// how many it changed. Without this, totals recorded before the change
  /// would count spending as income.
  Future<int> normalizeAmountSigns(String ownerId) async {
    final rows =
        await (_db.select(_db.transactions).join([
          leftOuterJoin(
            _db.categories,
            _db.categories.id.equalsExp(_db.transactions.categoryId),
          ),
        ])..where(
              _db.transactions.ownerId.equals(ownerId) &
                  _db.transactions.deletedAt.isNull(),
            ))
            .get();

    var fixed = 0;

    for (final row in rows) {
      final transaction = row.readTable(_db.transactions);
      final kind = CategoryKind.fromStorage(
        row.readTableOrNull(_db.categories)?.kind,
      );

      final expected = kind == CategoryKind.income
          ? transaction.amountScaled.abs()
          : -transaction.amountScaled.abs();

      if (expected == transaction.amountScaled) continue;

      await (_db.update(_db.transactions)
            ..where((t) => t.id.equals(transaction.id)))
          .write(
            TransactionsCompanion(
              amountScaled: Value(expected),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      fixed++;
    }

    return fixed;
  }

  /// Applies the ledger sign for the category's kind.
  ///
  /// Income is stored positive and spending negative, so summing a mixed set
  /// of rows gives income minus spending without any of the readers needing
  /// to know which is which. Callers pass a magnitude; the sign is not theirs
  /// to decide, and a UI that got it wrong would corrupt every total.
  Future<int> _signFor({
    required String ownerId,
    required String categoryId,
    required int amountScaled,
  }) async {
    final category =
        await (_db.select(_db.categories)
              ..where(
                (row) =>
                    row.id.equals(categoryId) & row.ownerId.equals(ownerId),
              )
              ..limit(1))
            .getSingleOrNull();

    final isIncome =
        CategoryKind.fromStorage(category?.kind) == CategoryKind.income;

    return isIncome ? amountScaled.abs() : -amountScaled.abs();
  }

  /// Changes an existing entry.
  ///
  /// Scoped by owner as well as id: without it a client that guessed an id
  /// could edit a row it does not own, and the local views enforce nothing.
  Future<void> updateSpend({
    required String ownerId,
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
  }) async {
    final existing = await _requireOwned(id, ownerId);

    // Re-signed from the row's own category: an edit must not be able to flip
    // an expense into income by typing a positive number.
    final signed = existing.categoryId == null
        ? -amountScaled.abs()
        : await _signFor(
            ownerId: ownerId,
            categoryId: existing.categoryId!,
            amountScaled: amountScaled,
          );

    await (_db.update(_db.transactions)..where(
          (row) => row.id.equals(id) & row.ownerId.equals(ownerId),
        ))
        .write(
          TransactionsCompanion(
            amountScaled: Value(signed),
            executedAt: occurredAt == null
                ? const Value.absent()
                : Value(occurredAt),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Throws unless a live row with [id] belongs to [ownerId].
  ///
  /// A SELECT rather than the row count a write returns: PowerSync's tables
  /// are views written through INSTEAD OF triggers, and SQLite does not count
  /// rows changed by such a trigger, so `write()` returns 0 even on success.
  Future<TransactionRow> _requireOwned(String id, String ownerId) async {
    final row =
        await (_db.select(_db.transactions)..where(
              (row) =>
                  row.id.equals(id) &
                  row.ownerId.equals(ownerId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) throw StateError('No transaction $id owned by $ownerId');
    return row;
  }

  /// Tombstones an entry.
  ///
  /// Sets `deleted_at` rather than issuing a DELETE, so the removal itself
  /// syncs. Reads filter these out.
  Future<void> deleteSpend({
    required String ownerId,
    required String id,
  }) async {
    await _requireOwned(id, ownerId);

    final now = DateTime.now().toUtc();

    await (_db.update(_db.transactions)..where(
          (row) => row.id.equals(id) & row.ownerId.equals(ownerId),
        ))
        .write(
          TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        );
  }

  /// A category's entries, newest first.
  Stream<List<SpendEntry>> watchCategoryHistory({
    required String ownerId,
    required String categoryId,
  }) {
    final query = _db.select(_db.transactions)
      ..where(
        (row) =>
            row.ownerId.equals(ownerId) &
            row.categoryId.equals(categoryId) &
            row.deletedAt.isNull(),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.executedAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => SpendEntry(
              id: row.id,
              amountScaled: row.amountScaled,
              occurredAt: row.executedAt,
              note: row.note,
            ),
          )
          .toList(),
    );
  }
}
