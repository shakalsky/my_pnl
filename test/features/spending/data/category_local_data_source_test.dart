import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';

void main() {
  group('CategoryLocalDataSource', () {
    late AppDatabase db;
    late CategoryLocalDataSource dataSource;

    const owner = 'user-1';
    const other = 'user-2';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dataSource = CategoryLocalDataSource(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<String> insertAccount() async {
      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              ownerId: owner,
              name: 'Everyday',
              currency: 'USD',
            ),
          );
      return account.id;
    }

    Future<void> insertTransaction({
      required String accountId,
      required String categoryId,
      required int amountScaled,
      String ownerId = owner,
      DateTime? executedAt,
    }) {
      return db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              ownerId: ownerId,
              accountId: accountId,
              categoryId: Value(categoryId),
              side: TradeSide.buy,
              amountScaled: amountScaled,
              currency: 'USD',
              executedAt: executedAt ?? DateTime.utc(2026, 3, 14),
            ),
          );
    }

    test('creates a category with a client-generated id', () async {
      final created = await dataSource.createCategory(
        const NewCategory(
          name: 'Groceries',
          colorArgb: 0xFF3B7A57,
          iconKey: 'groceries',
        ),
        owner,
      );

      expect(created.id, hasLength(36));
      expect(created.id[14], '7', reason: 'UUIDv7 version nibble');
      expect(created.name, 'Groceries');
      expect(created.iconKey, 'groceries');
    });

    test('refuses a name the owner already has', () async {
      await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );

      await expectLater(
        dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 2, iconKey: 'd'),
          owner,
        ),
        throwsA(isA<CategoryFailure>()),
      );
    });

    test('matches names case- and space-insensitively', () async {
      await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );

      await expectLater(
        dataSource.createCategory(
          const NewCategory(name: '  groceries ', colorArgb: 2, iconKey: 'd'),
          owner,
        ),
        throwsA(isA<CategoryFailure>()),
      );
    });

    test('lets a different owner use the same name', () async {
      await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );

      await expectLater(
        dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          other,
        ),
        completes,
      );
    });

    test('a deleted name can be used again', () async {
      final category = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );
      await dataSource.deleteCategory(
        ownerId: owner,
        id: category.id,
        mode: CategoryDeletion.keepTransactions,
      );

      await expectLater(
        dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        ),
        completes,
      );
    });

    test('renaming onto another category is refused', () async {
      final groceries = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );
      await dataSource.createCategory(
        const NewCategory(name: 'Dining', colorArgb: 2, iconKey: 'd'),
        owner,
      );

      await expectLater(
        dataSource.updateCategory(
          Category(
            id: groceries.id,
            name: 'Dining',
            colorArgb: 1,
            iconKey: 'g',
          ),
          owner,
        ),
        throwsA(isA<CategoryFailure>()),
      );
    });

    test('saving a category under its own name is allowed', () async {
      final groceries = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );

      final updated = await dataSource.updateCategory(
        Category(
          id: groceries.id,
          name: 'Groceries',
          colorArgb: 99,
          iconKey: 'dining',
        ),
        owner,
      );

      expect(updated.colorArgb, 99);
    });

    test('reports a category with no transactions as zero', () async {
      await dataSource.createCategory(
        const NewCategory(name: 'Fun', colorArgb: 1, iconKey: 'fun'),
        owner,
      );

      final spend = await dataSource
          .watchCategorySpend(owner, CategoryKind.expense)
          .first;

      expect(spend, hasLength(1));
      expect(spend.single.totalScaled, 0);
    });

    test('sums the transactions booked against each category', () async {
      final accountId = await insertAccount();
      final groceries = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );
      final dining = await dataSource.createCategory(
        const NewCategory(name: 'Dining', colorArgb: 2, iconKey: 'd'),
        owner,
      );

      for (final amount in [1250, 2000, 375]) {
        await insertTransaction(
          accountId: accountId,
          categoryId: groceries.id,
          amountScaled: amount,
        );
      }
      await insertTransaction(
        accountId: accountId,
        categoryId: dining.id,
        amountScaled: 4999,
      );

      final spend = await dataSource
          .watchCategorySpend(owner, CategoryKind.expense)
          .first;
      final byName = {
        for (final entry in spend) entry.category.name: entry.totalScaled,
      };

      expect(byName['Groceries'], 3625);
      expect(byName['Dining'], 4999);
      // 36.25 spent on groceries, held as an integer the whole way.
      expect(byName['Groceries']! / amountScale, 36.25);
    });

    test('excludes soft-deleted transactions from the total', () async {
      final accountId = await insertAccount();
      final category = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );

      await insertTransaction(
        accountId: accountId,
        categoryId: category.id,
        amountScaled: 1000,
      );
      await insertTransaction(
        accountId: accountId,
        categoryId: category.id,
        amountScaled: 500,
      );
      await (db.update(db.transactions)
            ..where((t) => t.amountScaled.equals(500)))
          .write(TransactionsCompanion(deletedAt: Value(DateTime.now())));

      final spend = await dataSource
          .watchCategorySpend(owner, CategoryKind.expense)
          .first;

      expect(spend.single.totalScaled, 1000);
    });

    test("never returns another owner's categories", () async {
      await dataSource.createCategory(
        const NewCategory(name: 'Mine', colorArgb: 1, iconKey: 'g'),
        owner,
      );
      await dataSource.createCategory(
        const NewCategory(name: 'Theirs', colorArgb: 1, iconKey: 'g'),
        other,
      );

      final spend = await dataSource
          .watchCategorySpend(owner, CategoryKind.expense)
          .first;

      expect(spend.map((e) => e.category.name), ['Mine']);
    });

    test('deleting keeps the transactions and detaches them', () async {
      final accountId = await insertAccount();
      final category = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );
      await insertTransaction(
        accountId: accountId,
        categoryId: category.id,
        amountScaled: 1250,
      );

      await dataSource.deleteCategory(
        ownerId: owner,
        id: category.id,
        mode: CategoryDeletion.keepTransactions,
      );

      expect(
        await dataSource.watchCategorySpend(owner, CategoryKind.expense).first,
        isEmpty,
      );

      // The money is still recorded, just no longer labelled.
      final transaction = await db.select(db.transactions).getSingle();
      expect(transaction.deletedAt, isNull);
      expect(transaction.amountScaled, 1250);
      expect(transaction.categoryId, isNull);

      // The category row survives as a tombstone so the delete can sync.
      final row = await db.select(db.categories).getSingle();
      expect(row.deletedAt, isNotNull);
    });

    test('deleting with deleteTransactions tombstones them too', () async {
      final accountId = await insertAccount();
      final category = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );
      await insertTransaction(
        accountId: accountId,
        categoryId: category.id,
        amountScaled: 1250,
      );

      await dataSource.deleteCategory(
        ownerId: owner,
        id: category.id,
        mode: CategoryDeletion.deleteTransactions,
      );

      final row = await db.select(db.transactions).getSingle();
      expect(row.deletedAt, isNotNull, reason: 'gone from every total');
      expect(row.categoryId, category.id, reason: 'still says where it was');
    });

    test("refuses to delete another owner's category", () async {
      final category = await dataSource.createCategory(
        const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
        owner,
      );

      await expectLater(
        dataSource.deleteCategory(
          ownerId: other,
          id: category.id,
          mode: CategoryDeletion.keepTransactions,
        ),
        throwsStateError,
      );
      expect(
        await dataSource.watchCategorySpend(owner, CategoryKind.expense).first,
        hasLength(1),
      );
    });

    test('re-emits when a category is added', () async {
      final emissions = <int>[];
      final subscription = dataSource
          .watchCategorySpend(owner, CategoryKind.expense)
          .listen((spend) => emissions.add(spend.length));

      // Let the initial query land before writing, otherwise the insert can
      // beat the first emission and the empty state is never observed.
      await pumpEventQueue();

      await dataSource.createCategory(
        const NewCategory(name: 'Fun', colorArgb: 1, iconKey: 'fun'),
        owner,
      );
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions, [0, 1]);
    });

    group('one month at a time', () {
      /// Groceries with 12.50 booked in March and 30.00 in April, plus a Fun
      /// category that was never used.
      Future<void> seedTwoMonths() async {
        final accountId = await insertAccount();
        final groceries = await dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        );
        await dataSource.createCategory(
          const NewCategory(name: 'Fun', colorArgb: 2, iconKey: 'fun'),
          owner,
        );

        await insertTransaction(
          accountId: accountId,
          categoryId: groceries.id,
          amountScaled: 1250,
          executedAt: DateTime.utc(2026, 3, 14),
        );
        await insertTransaction(
          accountId: accountId,
          categoryId: groceries.id,
          amountScaled: 3000,
          executedAt: DateTime.utc(2026, 4),
        );
      }

      test('totals only what that month holds', () async {
        await seedTwoMonths();

        final march = await dataSource
            .watchCategorySpend(
              owner,
              CategoryKind.expense,
              month: const CalendarMonth(2026, 3),
            )
            .first;

        expect(march.map((spend) => spend.totalScaled), [1250, 0]);
      });

      test('keeps every category in a month nothing was booked in', () async {
        await seedTwoMonths();

        final february = await dataSource
            .watchCategorySpend(
              owner,
              CategoryKind.expense,
              month: const CalendarMonth(2026, 2),
            )
            .first;

        // The grid is a list of categories, not of the ones that were used, so
        // paging back through a quiet month must not empty it.
        expect(february, hasLength(2));
        expect(february.every((spend) => spend.totalScaled == 0), isTrue);
      });

      test('counts everything with no month asked for', () async {
        await seedTwoMonths();

        final all = await dataSource
            .watchCategorySpend(owner, CategoryKind.expense)
            .first;

        expect(all.first.totalScaled, 4250);
      });

      test('reads the month in UTC', () async {
        final accountId = await insertAccount();
        final groceries = await dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        );

        // Half an hour into April, UTC. A local reading east of Greenwich would
        // call this March and file the entry in the month before.
        await insertTransaction(
          accountId: accountId,
          categoryId: groceries.id,
          amountScaled: 500,
          executedAt: DateTime.utc(2026, 4, 1, 0, 30),
        );

        Future<int> totalFor(CalendarMonth month) async =>
            (await dataSource
                    .watchCategorySpend(
                      owner,
                      CategoryKind.expense,
                      month: month,
                    )
                    .first)
                .single
                .totalScaled;

        expect(await totalFor(const CalendarMonth(2026, 4)), 500);
        expect(await totalFor(const CalendarMonth(2026, 3)), 0);
      });
    });

    group('what a month usually costs', () {
      const june = CalendarMonth(2026, 6);

      /// Books [amounts] against [categoryId], one per month, starting in
      /// [from] and stepping forward a month at a time.
      Future<void> bookMonthly({
        required String accountId,
        required String categoryId,
        required CalendarMonth from,
        required List<int> amounts,
      }) async {
        var month = from;

        for (final amount in amounts) {
          if (amount != 0) {
            await insertTransaction(
              accountId: accountId,
              categoryId: categoryId,
              amountScaled: amount,
              executedAt: DateTime.utc(month.year, month.month, 10),
            );
          }
          month = month.next;
        }
      }

      Future<Map<String, SpendBaseline>> baselines({
        CalendarMonth month = june,
        int lookbackMonths = SpendBaseline.lookbackMonths,
      }) => dataSource
          .watchSpendBaselines(
            owner,
            CategoryKind.expense,
            month: month,
            lookbackMonths: lookbackMonths,
          )
          .first;

      test('averages the months before the one asked about', () async {
        final accountId = await insertAccount();
        final groceries = await dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        );

        // March, April, May: 100, 200, 300 — and 900 in June itself, which is
        // the month being asked about.
        await bookMonthly(
          accountId: accountId,
          categoryId: groceries.id,
          from: const CalendarMonth(2026, 3),
          amounts: [-10000, -20000, -30000, -90000],
        );

        final baseline = (await baselines())[groceries.id]!;

        // 200, not 375: a month inside its own average moves that average, and
        // the spike would flatten itself.
        expect(baseline.averageScaled, 20000);
        expect(baseline.months, 3);
      });

      test('averages magnitudes, whichever way the ledger stores them',
          () async {
        final accountId = await insertAccount();
        final salary = await dataSource.createCategory(
          const NewCategory(
            name: 'Salary',
            colorArgb: 1,
            iconKey: 'home',
            kind: CategoryKind.income,
          ),
          owner,
        );

        await bookMonthly(
          accountId: accountId,
          categoryId: salary.id,
          from: const CalendarMonth(2026, 4),
          amounts: [300000, 300000],
        );

        final found = await dataSource
            .watchSpendBaselines(owner, CategoryKind.income, month: june)
            .first;

        expect(found[salary.id]?.averageScaled, 300000);
      });

      test('counts only the months something was booked in', () async {
        final accountId = await insertAccount();
        final travel = await dataSource.createCategory(
          const NewCategory(name: 'Travel', colorArgb: 1, iconKey: 'travel'),
          owner,
        );

        // Nothing in April: a month the category was quiet is not a month it
        // cost nothing, and averaging it in as zero would make an ordinary
        // month look like a spike.
        await bookMonthly(
          accountId: accountId,
          categoryId: travel.id,
          from: const CalendarMonth(2026, 3),
          amounts: [-10000, 0, -20000],
        );

        final baseline = (await baselines())[travel.id]!;

        expect(baseline.averageScaled, 15000);
        expect(baseline.months, 2);
      });

      test('adds up everything booked within one month', () async {
        final accountId = await insertAccount();
        final dining = await dataSource.createCategory(
          const NewCategory(name: 'Dining', colorArgb: 1, iconKey: 'dining'),
          owner,
        );

        for (final day in [3, 14, 28]) {
          await insertTransaction(
            accountId: accountId,
            categoryId: dining.id,
            amountScaled: -1000,
            executedAt: DateTime.utc(2026, 4, day),
          );
        }
        await insertTransaction(
          accountId: accountId,
          categoryId: dining.id,
          amountScaled: -6000,
          executedAt: DateTime.utc(2026, 5, 9),
        );

        final baseline = (await baselines())[dining.id]!;

        // Two months of 30 and 60, not five entries averaged one by one.
        expect(baseline.months, 2);
        expect(baseline.averageScaled, 4500);
      });

      test('reaches back no further than the lookback', () async {
        final accountId = await insertAccount();
        final rent = await dataSource.createCategory(
          const NewCategory(name: 'Rent', colorArgb: 1, iconKey: 'home'),
          owner,
        );

        // January through May, with January far out of line. A two-month
        // lookback sees April and May only.
        await bookMonthly(
          accountId: accountId,
          categoryId: rent.id,
          from: const CalendarMonth(2026, 1),
          amounts: [-500000, -10000, -10000, -10000, -10000],
        );

        final near = (await baselines(lookbackMonths: 2))[rent.id]!;
        expect(near.months, 2);
        expect(near.averageScaled, 10000);

        // Five months back reaches January, and the outlier is in the average.
        final far = (await baselines(lookbackMonths: 5))[rent.id]!;
        expect(far.months, 5);
        expect(far.averageScaled, greaterThan(near.averageScaled));
      });

      test('crosses a year boundary without losing a month', () async {
        final accountId = await insertAccount();
        final utilities = await dataSource.createCategory(
          const NewCategory(name: 'Utilities', colorArgb: 1, iconKey: 'build'),
          owner,
        );

        // November, December, January — the window for February 2027 spans the
        // turn of the year.
        await bookMonthly(
          accountId: accountId,
          categoryId: utilities.id,
          from: const CalendarMonth(2026, 11),
          amounts: [-10000, -20000, -30000],
        );

        final baseline =
            (await baselines(month: const CalendarMonth(2027, 2)))[utilities
                .id]!;

        expect(baseline.months, 3);
        expect(baseline.averageScaled, 20000);
      });

      test('leaves out a category with nothing booked in the window', () async {
        await insertAccount();
        final fun = await dataSource.createCategory(
          const NewCategory(name: 'Fun', colorArgb: 1, iconKey: 'fun'),
          owner,
        );

        // Absent rather than present with a zero average: "no usual month on
        // record" and "usually costs nothing" are different answers.
        expect(await baselines(), isNot(contains(fun.id)));
      });

      test('keeps one owner out of another’s usual month', () async {
        final accountId = await insertAccount();
        final mine = await dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        );

        await bookMonthly(
          accountId: accountId,
          categoryId: mine.id,
          from: const CalendarMonth(2026, 4),
          amounts: [-10000, -10000],
        );
        // Booked against the same category by someone else — impossible through
        // the repository, which is why the query has to refuse it here.
        await insertTransaction(
          accountId: accountId,
          categoryId: mine.id,
          amountScaled: -900000,
          ownerId: other,
          executedAt: DateTime.utc(2026, 5, 20),
        );

        expect((await baselines())[mine.id]?.averageScaled, 10000);
      });

      test('leaves out a deleted entry', () async {
        final accountId = await insertAccount();
        final health = await dataSource.createCategory(
          const NewCategory(name: 'Health', colorArgb: 1, iconKey: 'health'),
          owner,
        );

        await bookMonthly(
          accountId: accountId,
          categoryId: health.id,
          from: const CalendarMonth(2026, 4),
          amounts: [-10000, -10000],
        );
        await insertTransaction(
          accountId: accountId,
          categoryId: health.id,
          amountScaled: -50000,
          executedAt: DateTime.utc(2026, 5, 21),
        );
        await (db.update(db.transactions)..where(
              (row) => row.amountScaled.equals(-50000),
            ))
            .write(TransactionsCompanion(deletedAt: Value(DateTime.utc(2026))));

        expect((await baselines())[health.id]?.averageScaled, 10000);
      });

      test('shows the other side of the ledger nothing of this one', () async {
        final accountId = await insertAccount();
        final groceries = await dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        );

        await bookMonthly(
          accountId: accountId,
          categoryId: groceries.id,
          from: const CalendarMonth(2026, 4),
          amounts: [-10000, -10000],
        );

        final income = await dataSource
            .watchSpendBaselines(owner, CategoryKind.income, month: june)
            .first;

        expect(income, isEmpty);
      });

      test('re-emits when an entry in the window changes', () async {
        final accountId = await insertAccount();
        final groceries = await dataSource.createCategory(
          const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'g'),
          owner,
        );

        final stream = dataSource
            .watchSpendBaselines(owner, CategoryKind.expense, month: june)
            .distinct();
        final seen = expectLater(
          stream,
          emitsInOrder(<Object>[
            isEmpty,
            {groceries.id: const SpendBaseline(averageScaled: 10000, months: 2)},
          ]),
        );

        await bookMonthly(
          accountId: accountId,
          categoryId: groceries.id,
          from: const CalendarMonth(2026, 4),
          amounts: [-10000, -10000],
        );

        await seen;
      });
    });
  });
}
