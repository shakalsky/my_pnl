import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/spending/data/datasources/account_local_data_source.dart';
import 'package:my_pnl/features/spending/data/mappers/category_mapper.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Drift writes behind the transaction repository.
///
/// Two scopes run through everything here, and keeping them apart is what makes
/// a family account safe:
///
/// * reads narrow on `ledger_id`, so both partners' entries are counted;
/// * writes narrow on `owner_id` as well, so neither can change the other's.
///
/// The Postgres policies enforce the same split. These filters are not the
/// security boundary — they are what stops the app offering an action the server
/// would refuse.
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
    required String ledgerId,
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) async {
    final accountId = await _accounts.defaultAccountId(
      ownerId: ownerId,
      ledgerId: ledgerId,
    );
    final signed = await _signFor(
      ledgerId: ledgerId,
      categoryId: categoryId,
      amountScaled: amountScaled,
    );

    await _db
        .into(_db.transactions)
        .insert(
          TransactionsCompanion.insert(
            ownerId: ownerId,
            ledgerId: Value(ledgerId),
            accountId: accountId,
            categoryId: Value(categoryId),
            side: TradeSide.buy,
            amountScaled: signed,
            currency: defaultCurrency,
            executedAt: occurredAt ?? DateTime.now().toUtc(),
            note: Value(note),
          ),
        );
  }

  /// Every entry in the ledger, newest first, with its category and author.
  ///
  /// A left join on the category: an entry whose category was deleted with its
  /// entries kept still belongs in the ledger, and dropping it here would make
  /// the list disagree with the net total.
  ///
  /// A left join on the membership too, which is how a partner's entry gets a
  /// name beside it. Left rather than inner for the same reason: a member who
  /// has left is gone from that table, and their spending stays in the book.
  ///
  /// [month] narrows it to one UTC month, the same month the overview's totals
  /// are read for. Unlike the category grid, the filter belongs in the `where`:
  /// this is a list of entries, and an entry outside the month is not one of
  /// them. Null lists the whole ledger.
  Stream<List<LedgerEntry>> watchAllEntries({
    required String ledgerId,
    required String viewerId,
    CalendarMonth? month,
  }) {
    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.categories,
              _db.categories.id.equalsExp(_db.transactions.categoryId) &
                  _db.categories.deletedAt.isNull(),
            ),
            leftOuterJoin(
              _db.ledgerMembers,
              _db.ledgerMembers.ledgerId.equalsExp(_db.transactions.ledgerId) &
                  _db.ledgerMembers.userId.equalsExp(_db.transactions.ownerId),
            ),
          ])
          ..where(
            _db.transactions.ledgerId.equals(ledgerId) &
                _db.transactions.deletedAt.isNull() &
                _bookedIn(month),
          )
          ..orderBy([OrderingTerm.desc(_db.transactions.executedAt)])
          ..limit(allEntriesLimit);

    return query.watch().map(
      (rows) => rows.map((row) {
        final transaction = row.readTable(_db.transactions);

        return LedgerEntry(
          entry: _toEntry(
            transaction,
            viewerId: viewerId,
            author: row.readTableOrNull(_db.ledgerMembers),
          ),
          category: row.readTableOrNull(_db.categories)?.toEntity(),
        );
      }).toList(),
    );
  }

  /// Income minus spending, across every category in the ledger.
  ///
  /// A plain SUM: because income is stored positive and spending negative,
  /// the subtraction is already in the data. Both partners' rows are in it,
  /// which is the figure the overview is asking for.
  ///
  /// [month] narrows it to one UTC month, read the same way `watchMonthlyPnl`
  /// groups them, so the figure for a month agrees with that month's row there.
  /// Null sums the whole ledger.
  Stream<int> watchNetTotal(String ledgerId, {CalendarMonth? month}) {
    final total = _db.transactions.amountScaled.sum();

    final query = _db.selectOnly(_db.transactions)
      ..addColumns([total])
      ..where(
        _db.transactions.ledgerId.equals(ledgerId) &
            _db.transactions.deletedAt.isNull() &
            _bookedIn(month),
      );

    return query.watchSingle().map((row) => row.read(total) ?? 0);
  }

  /// Matches a transaction booked in [month] — or every transaction, when no
  /// month is asked for.
  ///
  /// The month is read with the date functions rather than by comparing the
  /// stored text to a range, so it is a UTC month exactly as [watchMonthlyPnl]
  /// groups them. A device an hour either side of the boundary then cannot move
  /// an entry between months just by travelling, and a figure here agrees with
  /// the month's row there.
  Expression<bool> _bookedIn(CalendarMonth? month) {
    // `AND 1` when there is no month, which SQLite folds away, and which keeps
    // every caller's `where` in one piece rather than assembled in two
    // branches.
    if (month == null) return const Constant<bool>(true);

    // See `watchMonthlyPnl` on the cast: the column carries a type converter,
    // so drift types it as the String it is stored as. `dartCast` puts the
    // DateTime back for the sake of the date functions and changes no SQL —
    // they read the ISO-8601 text exactly as it stands.
    final executedAt = _db.transactions.executedAt.dartCast<DateTime>();

    return executedAt.year.equals(month.year) &
        executedAt.month.equals(month.month);
  }

  /// Income minus spending per calendar month, newest first.
  ///
  /// Grouped in the database rather than in Dart: the ledger is unbounded, and
  /// pulling every row across to add it up would get slower every month.
  ///
  /// The month comes from `strftime` over the stored UTC timestamp, so months
  /// are UTC months. A device an hour either side of the boundary would
  /// otherwise move an entry between months just by travelling.
  Stream<List<MonthlyPnl>> watchMonthlyPnl(String ledgerId) {
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
        _db.transactions.ledgerId.equals(ledgerId) &
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
  ///
  /// Scoped by owner and not by ledger: a sign is wrong wherever the row sits,
  /// and these are exactly the rows this user is allowed to rewrite. A partner's
  /// rows are their own device's business.
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

      await (_db.update(
        _db.transactions,
      )..where((t) => t.id.equals(transaction.id))).write(
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
  ///
  /// Scoped to the ledger, which doubles as the check that the category is one
  /// this book has. Booking against a category from another ledger would put a
  /// row in totals nobody can see the category for.
  Future<int> _signFor({
    required String ledgerId,
    required String categoryId,
    required int amountScaled,
  }) async {
    final category =
        await (_db.select(_db.categories)
              ..where(
                (row) =>
                    row.id.equals(categoryId) & row.ledgerId.equals(ledgerId),
              )
              ..limit(1))
            .getSingleOrNull();

    if (category == null) {
      throw StateError('No category $categoryId in ledger $ledgerId');
    }

    final isIncome =
        CategoryKind.fromStorage(category.kind) == CategoryKind.income;

    return isIncome ? amountScaled.abs() : -amountScaled.abs();
  }

  /// Changes an existing entry.
  ///
  /// Scoped by owner as well as id, and that is the family-account rule rather
  /// than paranoia: a partner reads these rows and must not be able to rewrite
  /// them. The local views enforce nothing, so this filter and the matching
  /// Postgres policy are what does.
  Future<void> updateSpend({
    required String ownerId,
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) async {
    final existing = await _requireOwned(id, ownerId);

    // Re-signed from the row's own category: an edit must not be able to flip
    // an expense into income by typing a positive number.
    final signed = switch ((existing.categoryId, existing.ledgerId)) {
      (final String categoryId, final String ledgerId) => await _signFor(
        ledgerId: ledgerId,
        categoryId: categoryId,
        amountScaled: amountScaled,
      ),
      // No category to take a kind from — an entry left uncategorised, or one
      // the startup pass has not given a ledger yet — so it stays spending,
      // which is what an uncategorised amount has always counted as.
      _ => -amountScaled.abs(),
    };

    await (_db.update(_db.transactions)..where(
          (row) => row.id.equals(id) & row.ownerId.equals(ownerId),
        ))
        .write(
          TransactionsCompanion(
            amountScaled: Value(signed),
            executedAt: occurredAt == null
                ? const Value.absent()
                : Value(occurredAt),
            // Written unconditionally, unlike the date above: a cleared note is
            // an edit like any other, and treating null as "leave it alone"
            // would make the field impossible to empty.
            note: Value(note),
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

  /// A category's entries, newest first, whoever recorded them.
  ///
  /// [month] narrows it to one UTC month, which is what makes the list add up
  /// to the total on the tile it was opened from. Null lists the whole history.
  Stream<List<SpendEntry>> watchCategoryHistory({
    required String ledgerId,
    required String viewerId,
    required String categoryId,
    CalendarMonth? month,
  }) {
    final query =
        _db.select(_db.transactions).join([
            leftOuterJoin(
              _db.ledgerMembers,
              _db.ledgerMembers.ledgerId.equalsExp(_db.transactions.ledgerId) &
                  _db.ledgerMembers.userId.equalsExp(_db.transactions.ownerId),
            ),
          ])
          ..where(
            _db.transactions.ledgerId.equals(ledgerId) &
                _db.transactions.categoryId.equals(categoryId) &
                _db.transactions.deletedAt.isNull() &
                _bookedIn(month),
          )
          ..orderBy([OrderingTerm.desc(_db.transactions.executedAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => _toEntry(
              row.readTable(_db.transactions),
              viewerId: viewerId,
              author: row.readTableOrNull(_db.ledgerMembers),
            ),
          )
          .toList(),
    );
  }

  /// Builds the entry, working out whether the reader may change it.
  SpendEntry _toEntry(
    TransactionRow row, {
    required String viewerId,
    required LedgerMemberRow? author,
  }) {
    final isOwn = row.ownerId == viewerId;

    return SpendEntry(
      id: row.id,
      amountScaled: row.amountScaled,
      occurredAt: row.executedAt,
      note: row.note,
      isOwn: isOwn,
      // Resolved here rather than in the UI, so a stored sign-in email cannot
      // reach the screen by a route that forgot to shorten it.
      authorName: isOwn ? null : ledgerMemberLabel(author?.displayName),
    );
  }
}
