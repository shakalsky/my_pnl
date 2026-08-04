import 'package:drift/drift.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/data/datasources/account_local_data_source.dart';
import 'package:my_pnl/features/spending/data/mappers/category_mapper.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

/// Drift queries behind the category repository.
///
/// Under PowerSync these tables are views over the synced data, so a row
/// arriving from another device shows up here the same way a local write
/// does — the watch stream fires either way.
class CategoryLocalDataSource {
  const CategoryLocalDataSource(this._db);

  final AppDatabase _db;

  AccountLocalDataSource get _accounts => AccountLocalDataSource(_db);

  /// How far back a first run will reach when catching up.
  ///
  /// Without a bound, a category dated years ago would generate a wall of
  /// transactions nobody asked for on the first launch after an import.
  static const maxCatchUpMonths = 24;

  /// Books every recurring income occurrence that has come due.
  ///
  /// Walks month by month from the category's creation to [now], so an app
  /// closed for a quarter still books the months it missed. Returns how many
  /// transactions were created.
  Future<int> generateDueRecurringIncome({
    required String ownerId,
    required DateTime now,
  }) async {
    final categories =
        await (_db.select(_db.categories)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.deletedAt.isNull() &
                  row.kind.equals(CategoryKind.income.storage) &
                  row.recurringDayOfMonth.isNotNull() &
                  row.recurringAmountScaled.isNotNull(),
            ))
            .get();

    if (categories.isEmpty) return 0;

    final nowUtc = now.toUtc();
    var created = 0;

    for (final row in categories) {
      final category = row.toEntity();
      final recurring = category.recurring!;

      for (final occurrence in _dueOccurrences(
        from: row.createdAt,
        until: nowUtc,
        dayOfMonth: recurring.dayOfMonth,
      )) {
        final id = derivedId(
          'recurring:${category.id}:${occurrence.year}-${occurrence.month}',
        );

        // Checked without filtering tombstones on purpose: an occurrence the
        // user deleted must stay deleted rather than reappear next launch.
        final existing =
            await (_db.select(_db.transactions)
                  ..where((t) => t.id.equals(id))
                  ..limit(1))
                .getSingleOrNull();
        if (existing != null) continue;

        await _db
            .into(_db.transactions)
            .insert(
              TransactionsCompanion.insert(
                id: Value(id),
                ownerId: ownerId,
                accountId: await _accounts.defaultAccountId(ownerId),
                categoryId: Value(category.id),
                side: TradeSide.buy,
                amountScaled: recurring.amountScaled,
                currency: AccountLocalDataSource.defaultCurrency,
                executedAt: occurrence,
                note: Value(category.description),
              ),
            );
        created++;
      }
    }

    return created;
  }

  /// Every occurrence between [from] and [until], oldest first.
  ///
  /// [dayOfMonth] is clamped to the length of each month, so 31 means the last
  /// day of February rather than an occurrence February cannot have.
  ///
  /// An occurrence that fell before the category existed is skipped — setting
  /// up a salary on the 20th does not retroactively pay you on the 5th. By the
  /// same rule, a category created on its own pay day starts next month.
  Iterable<DateTime> _dueOccurrences({
    required DateTime from,
    required DateTime until,
    required int dayOfMonth,
  }) sync* {
    final createdAt = from.toUtc();
    final earliest = DateTime.utc(until.year, until.month - maxCatchUpMonths);
    final start = createdAt.isAfter(earliest) ? createdAt : earliest;

    var year = start.year;
    var month = start.month;

    while (true) {
      final daysInMonth = DateTime.utc(year, month + 1, 0).day;
      final occurrence = DateTime.utc(
        year,
        month,
        dayOfMonth < daysInMonth ? dayOfMonth : daysInMonth,
      );

      if (occurrence.isAfter(until)) return;
      if (!occurrence.isBefore(start)) yield occurrence;

      month++;
      if (month > 12) {
        month = 1;
        year++;
      }
    }
  }

  /// Categories with the sum of their transactions.
  ///
  /// A left join, so a category with no transactions still appears with a
  /// total of zero rather than dropping out of the list.
  ///
  /// [month] narrows the sum to one month. It is applied to the join and not to
  /// the `where`, because a condition on the right-hand table of a left join
  /// belongs to the match: in the `where` it would drop every category that had
  /// nothing booked that month, and the grid would empty out as the user paged
  /// back through quiet months.
  Stream<List<CategorySpend>> watchCategorySpend(
    String ownerId,
    CategoryKind kind, {
    CalendarMonth? month,
  }) {
    final total = _db.transactions.amountScaled.sum();

    final query =
        _db.select(_db.categories).join([
            leftOuterJoin(
              _db.transactions,
              _db.transactions.categoryId.equalsExp(_db.categories.id) &
                  _db.transactions.deletedAt.isNull() &
                  _bookedIn(month),
            ),
          ])
          ..where(
            _db.categories.ownerId.equals(ownerId) &
                _db.categories.deletedAt.isNull() &
                _kindMatches(kind),
          )
          ..addColumns([total])
          ..groupBy([_db.categories.id])
          ..orderBy([OrderingTerm.asc(_db.categories.createdAt)]);

    return query.watch().map(
      (rows) => rows
          .map(
            (row) => CategorySpend(
              category: row.readTable(_db.categories).toEntity(),
              totalScaled: row.read(total) ?? 0,
            ),
          )
          .toList(),
    );
  }

  /// What each category usually costs in a month, keyed by category id.
  ///
  /// Averages the [lookbackMonths] months ending with the one before [month].
  /// The month being looked at is left out of its own baseline on purpose: an
  /// average a figure is inside of moves with that figure, which is the one
  /// thing a comparison against it must not do.
  ///
  /// Grouped per category and month in the database, then averaged here. The
  /// division cannot go into the SQL because which months count is not a
  /// property of a row: only months with something booked in them do, and a
  /// month a category did not exist in is absent from the result rather than
  /// present as a zero. `AVG` over the rows would divide by the wrong number.
  Stream<Map<String, SpendBaseline>> watchSpendBaselines(
    String ownerId,
    CategoryKind kind, {
    required CalendarMonth month,
    int lookbackMonths = SpendBaseline.lookbackMonths,
  }) {
    // Same cast as `watchCategorySpend`, and for the same reason: the column is
    // stored as ISO-8601 text, and the date functions read it as it stands.
    final executedAt = _db.transactions.executedAt.dartCast<DateTime>();
    // Months since year zero, exactly as `CalendarMonth.ordinal` counts them,
    // so a window that crosses a year boundary needs no special case.
    final ordinal = executedAt.year * const Constant(12) + executedAt.month;
    final categoryId = _db.transactions.categoryId;
    final total = _db.transactions.amountScaled.sum();

    // The month before the one asked about, back through the window.
    final newest = month.ordinal - 1;
    final oldest = month.ordinal - lookbackMonths;

    final query =
        _db.selectOnly(_db.transactions).join([
            // Inner: a baseline is per category, so an entry whose category was
            // deleted has nothing here to be the usual month of.
            innerJoin(
              _db.categories,
              _db.categories.id.equalsExp(categoryId) &
                  _db.categories.ownerId.equals(ownerId) &
                  _db.categories.deletedAt.isNull() &
                  _kindMatches(kind),
            ),
          ])
          ..addColumns([categoryId, ordinal, total])
          ..where(
            _db.transactions.ownerId.equals(ownerId) &
                _db.transactions.deletedAt.isNull() &
                ordinal.isBetweenValues(oldest, newest),
          )
          ..groupBy([categoryId, ordinal]);

    return query.watch().map((rows) {
      final booked = <String, List<int>>{};

      for (final row in rows) {
        final id = row.read(categoryId);
        final monthTotal = row.read(total) ?? 0;
        // Magnitudes: spending is stored negative, and a baseline is compared
        // against either side of the ledger. A month that came to exactly zero
        // — a spend and its refund — is no evidence of a usual month, so it is
        // not counted as one.
        if (id == null || monthTotal == 0) continue;
        (booked[id] ??= []).add(monthTotal.abs());
      }

      return {
        for (final entry in booked.entries)
          entry.key: SpendBaseline(
            averageScaled:
                entry.value.reduce((sum, amount) => sum + amount) ~/
                entry.value.length,
            months: entry.value.length,
          ),
      };
    });
  }

  /// Matches a transaction booked in [month] — or every transaction, when no
  /// month is asked for.
  ///
  /// The month is read with the date functions rather than by comparing the
  /// stored text to a range, so it is a UTC month exactly as `watchMonthlyPnl`
  /// groups them. A device an hour either side of the boundary then cannot move
  /// an entry between months just by travelling.
  Expression<bool> _bookedIn(CalendarMonth? month) {
    // `AND 1` when there is no month, which SQLite folds away, and which keeps
    // the join condition in one piece rather than assembled in two branches.
    if (month == null) return const Constant<bool>(true);

    // The column carries a type converter, so drift types it as the String it
    // is stored as. `dartCast` puts the DateTime back for the sake of the date
    // functions and changes no SQL: they read the ISO-8601 text as it stands.
    final executedAt = _db.transactions.executedAt.dartCast<DateTime>();

    return executedAt.year.equals(month.year) &
        executedAt.month.equals(month.month);
  }

  /// Matches a category's kind, counting a missing value as expense.
  ///
  /// Rows written before the column existed sync down with kind null, and a
  /// plain `kind = 'expense'` would hide every one of them.
  Expression<bool> _kindMatches(CategoryKind kind) => switch (kind) {
    CategoryKind.expense =>
      _db.categories.kind.equals(kind.storage) | _db.categories.kind.isNull(),
    CategoryKind.income => _db.categories.kind.equals(kind.storage),
  };

  /// Inserts a category and returns the stored row.
  ///
  /// The id comes from the table's client-side UUIDv7 default, so it exists
  /// before the row ever reaches a server.
  Future<Category> createCategory(NewCategory category, String ownerId) async {
    await _requireFreeName(category.name, ownerId);

    final row = await _db
        .into(_db.categories)
        .insertReturning(
          CategoriesCompanion.insert(
            ownerId: ownerId,
            name: category.name,
            colorArgb: category.colorArgb,
            iconKey: category.iconKey,
            kind: Value(category.kind.storage),
            description: Value(category.description),
            recurringDayOfMonth: Value(category.recurring?.dayOfMonth),
            recurringAmountScaled: Value(category.recurring?.amountScaled),
          ),
        );

    return row.toEntity();
  }

  /// Applies edits to an existing category.
  ///
  /// `updatedAt` is bumped here rather than by a database trigger: PowerSync's
  /// local tables are views and cannot carry triggers, so the client is the
  /// only place that can stamp it before the change is queued for upload.
  Future<Category> updateCategory(Category category, String ownerId) async {
    await _requireOwned(category.id, ownerId);
    await _requireFreeName(category.name, ownerId, exceptId: category.id);

    await (_db.update(_db.categories)..where(
          (row) => row.id.equals(category.id) & row.ownerId.equals(ownerId),
        ))
        .write(
          CategoriesCompanion(
            name: Value(category.name),
            colorArgb: Value(category.colorArgb),
            iconKey: Value(category.iconKey),
            kind: Value(category.kind.storage),
            description: Value(category.description),
            recurringDayOfMonth: Value(category.recurring?.dayOfMonth),
            recurringAmountScaled: Value(category.recurring?.amountScaled),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );

    return (await _requireOwned(category.id, ownerId)).toEntity();
  }

  /// Throws if the owner already has a live category by this name.
  ///
  /// Compared case-insensitively: "Food" and "food" are the same category to
  /// anyone reading the grid, and allowing both makes the list confusing.
  /// PowerSync's local views carry no unique constraint, so this check is what
  /// enforces it on device; Postgres has the matching index.
  Future<void> _requireFreeName(
    String name,
    String ownerId, {
    String? exceptId,
  }) async {
    final normalized = name.trim().toLowerCase();

    final clash =
        await (_db.select(_db.categories)..where(
              (row) =>
                  row.ownerId.equals(ownerId) &
                  row.name.lower().equals(normalized) &
                  row.deletedAt.isNull(),
            ))
            .get();

    if (clash.any((row) => row.id != exceptId)) {
      throw CategoryFailure('You already have a category called "$name"');
    }
  }

  /// Reads a live row back, throwing if it is missing or not the caller's.
  ///
  /// Existence is checked with a SELECT rather than the row count a write
  /// returns. Under PowerSync these tables are views written through INSTEAD
  /// OF triggers, and SQLite does not count rows changed by such a trigger —
  /// so `write()` returns 0 on a perfectly successful update. Treating that
  /// as "not found" fails every edit and delete on a real device, while
  /// passing against the plain database used in tests.
  Future<CategoryRow> _requireOwned(String id, String ownerId) async {
    final row =
        await (_db.select(_db.categories)..where(
              (row) =>
                  row.id.equals(id) &
                  row.ownerId.equals(ownerId) &
                  row.deletedAt.isNull(),
            ))
            .getSingleOrNull();

    if (row == null) throw StateError('No category $id owned by $ownerId');
    return row;
  }

  /// Tombstones a category and detaches its transactions.
  ///
  /// Both writes happen in one transaction: a category removed while its
  /// transactions still pointed at it would leave rows referencing something
  /// no read returns, and the amounts would vanish from every total while
  /// still sitting in the table.
  ///
  /// What happens to the transactions is the caller's choice: [mode] either
  /// detaches them, leaving the money in the ledger, or tombstones them with
  /// the category.
  Future<void> deleteCategory({
    required String ownerId,
    required String id,
    required CategoryDeletion mode,
  }) async {
    final now = DateTime.now().toUtc();

    await _db.transaction(() async {
      await _requireOwned(id, ownerId);

      await (_db.update(_db.categories)..where(
            (row) => row.id.equals(id) & row.ownerId.equals(ownerId),
          ))
          .write(
            CategoriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
          );

      final booked = _db.update(_db.transactions)
        ..where(
          (row) =>
              row.ownerId.equals(ownerId) &
              row.categoryId.equals(id) &
              row.deletedAt.isNull(),
        );

      await switch (mode) {
        // Detached, not dropped: the money stays in the ledger and the net
        // total does not move.
        CategoryDeletion.keepTransactions => booked.write(
          TransactionsCompanion(
            categoryId: const Value(null),
            updatedAt: Value(now),
          ),
        ),
        // Tombstoned alongside the category, so the removal syncs.
        CategoryDeletion.deleteTransactions => booked.write(
          TransactionsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
        ),
      };
    });
  }
}
