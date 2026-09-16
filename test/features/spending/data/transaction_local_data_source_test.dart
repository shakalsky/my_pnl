import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/data/datasources/transaction_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';

void main() {
  group('TransactionLocalDataSource', () {
    late AppDatabase db;
    late TransactionLocalDataSource transactions;
    late CategoryLocalDataSource categories;

    const owner = 'user-1';
    const ledger = 'ledger-1';

    /// The other person in a shared book, for the rules that only show up when
    /// two people write into one.
    const partner = 'user-2';

    /// Another book, which nothing done to [ledger] may reach.
    const otherLedger = 'ledger-2';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      transactions = TransactionLocalDataSource(db);
      categories = CategoryLocalDataSource(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<Category> newCategory() => categories.createCategory(
      const NewCategory(name: 'Groceries', colorArgb: 1, iconKey: 'groceries'),
      ownerId: owner,
      ledgerId: ledger,
    );

    test('creates the default account on first use, then reuses it', () async {
      final category = await newCategory();

      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
      );
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 500,
      );

      final accounts = await db.select(db.accounts).get();
      expect(accounts, hasLength(1));
      expect(
        accounts.single.name,
        TransactionLocalDataSource.defaultAccountName,
      );
    });

    test('shows up in the category total', () async {
      final category = await newCategory();

      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
      );
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 500,
      );

      final spend = await categories
          .watchCategorySpend(ledger, CategoryKind.expense)
          .first;
      expect(spend.single.totalScaled, -1750, reason: 'spending is negative');
    });

    test('lists a category history newest first', () async {
      final category = await newCategory();

      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
        occurredAt: DateTime.utc(2026, 3, 10),
      );
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 500,
        occurredAt: DateTime.utc(2026, 3, 14),
      );

      final history = await transactions
          .watchCategoryHistory(
            ledgerId: ledger,
            viewerId: owner,
            categoryId: category.id,
          )
          .first;

      expect(history.map((e) => e.amountScaled), [-500, -1250]);
      expect(history.first.occurredAt, DateTime.utc(2026, 3, 14));
    });

    test('history excludes another category and soft-deleted rows', () async {
      final groceries = await newCategory();
      final dining = await categories.createCategory(
        const NewCategory(name: 'Dining', colorArgb: 2, iconKey: 'dining'),
        ownerId: owner,
        ledgerId: ledger,
      );

      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: groceries.id,
        amountScaled: 1250,
      );
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: dining.id,
        amountScaled: 999,
      );

      final history = await transactions
          .watchCategoryHistory(
            ledgerId: ledger,
            viewerId: owner,
            categoryId: groceries.id,
          )
          .first;

      expect(history.map((e) => e.amountScaled), [-1250]);
    });

    test('updating changes the amount and the category total', () async {
      final category = await newCategory();
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
      );
      final entry =
          (await transactions
                  .watchCategoryHistory(
                    ledgerId: ledger,
                    viewerId: owner,
                    categoryId: category.id,
                  )
                  .first)
              .single;

      await transactions.updateSpend(
        ownerId: owner,
        id: entry.id,
        amountScaled: 999,
      );

      final spend = await categories
          .watchCategorySpend(ledger, CategoryKind.expense)
          .first;
      expect(spend.single.totalScaled, -999);
    });

    test('the note survives the round trip, and can be cleared', () async {
      final category = await newCategory();
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
        note: 'Weekly shop',
      );

      Future<SpendEntry> only() async =>
          (await transactions
                  .watchCategoryHistory(
                    ledgerId: ledger,
                    viewerId: owner,
                    categoryId: category.id,
                  )
                  .first)
              .single;

      expect((await only()).note, 'Weekly shop');

      await transactions.updateSpend(
        ownerId: owner,
        id: (await only()).id,
        amountScaled: 1250,
      );

      // An edit that carries no note empties it, rather than leaving the old
      // one behind where the field the user cleared says otherwise.
      expect((await only()).note, isNull);
    });

    test('deleting tombstones the row rather than removing it', () async {
      final category = await newCategory();
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
      );
      final entry =
          (await transactions
                  .watchCategoryHistory(
                    ledgerId: ledger,
                    viewerId: owner,
                    categoryId: category.id,
                  )
                  .first)
              .single;

      await transactions.deleteSpend(ownerId: owner, id: entry.id);

      // Gone from every read...
      final history = await transactions
          .watchCategoryHistory(
            ledgerId: ledger,
            viewerId: owner,
            categoryId: category.id,
          )
          .first;
      expect(history, isEmpty);
      final spend = await categories
          .watchCategorySpend(ledger, CategoryKind.expense)
          .first;
      expect(spend.single.totalScaled, 0);

      // ...but still on disk, so the delete can sync to other devices.
      final row = await db.select(db.transactions).getSingle();
      expect(row.deletedAt, isNotNull);
      expect(row.deletedAt!.isUtc, isTrue);
    });

    test("refuses to touch another owner's entry", () async {
      final category = await newCategory();
      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 1250,
      );
      final entry =
          (await transactions
                  .watchCategoryHistory(
                    ledgerId: ledger,
                    viewerId: owner,
                    categoryId: category.id,
                  )
                  .first)
              .single;

      await expectLater(
        transactions.updateSpend(
          ownerId: 'user-2',
          id: entry.id,
          amountScaled: 1,
        ),
        throwsStateError,
      );
      await expectLater(
        transactions.deleteSpend(ownerId: 'user-2', id: entry.id),
        throwsStateError,
      );
    });

    test('stores the execution time as UTC', () async {
      final category = await newCategory();
      final local = DateTime(2026, 3, 14, 9, 30);

      await transactions.recordSpend(
        ownerId: owner,
        ledgerId: ledger,
        categoryId: category.id,
        amountScaled: 100,
        occurredAt: local,
      );

      final row = await db.select(db.transactions).getSingle();
      expect(row.executedAt.isUtc, isTrue);
      expect(row.executedAt, local.toUtc());
    });

    group('monthly P&L', () {
      /// A category on the given side of the ledger, so the sign is applied.
      Future<Category> categoryOf(CategoryKind kind, String name) =>
          categories.createCategory(
            NewCategory(name: name, colorArgb: 1, iconKey: 'x', kind: kind),
            ownerId: owner,
            ledgerId: ledger,
          );

      test('groups income and spending by calendar month', () async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');
        final rent = await categoryOf(CategoryKind.expense, 'Rent');

        // March: 3000 in, 1000 out — up 2000.
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: salary.id,
          amountScaled: 300000,
          occurredAt: DateTime.utc(2026, 3, 5),
        );
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: rent.id,
          amountScaled: 100000,
          occurredAt: DateTime.utc(2026, 3, 28),
        );
        // April: nothing in, 400 out — down 400.
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: rent.id,
          amountScaled: 40000,
          occurredAt: DateTime.utc(2026, 4, 2),
        );

        final months = await transactions.watchMonthlyPnl(ledger).first;

        // Newest first.
        expect(months, hasLength(2));
        expect(months.first.year, 2026);
        expect(months.first.month, 4);
        expect(months.first.netScaled, -40000);
        expect(months.first.isPositive, isFalse);

        expect(months.last.month, 3);
        expect(months.last.netScaled, 200000);
        expect(months.last.isPositive, isTrue);
      });

      test('leaves out months with nothing in them', () async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');

        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: salary.id,
          amountScaled: 100,
          occurredAt: DateTime.utc(2026),
        );
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: salary.id,
          amountScaled: 100,
          occurredAt: DateTime.utc(2026, 6),
        );

        final months = await transactions.watchMonthlyPnl(ledger).first;

        expect(
          months.map((month) => month.month),
          [6, 1],
          reason: 'February through May had no entries',
        );
      });

      test('ignores deleted entries', () async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');

        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: salary.id,
          amountScaled: 5000,
          occurredAt: DateTime.utc(2026, 7, 10),
        );
        final entry =
            (await transactions
                    .watchCategoryHistory(
                      ledgerId: ledger,
                      viewerId: owner,
                      categoryId: salary.id,
                    )
                    .first)
                .single;

        await transactions.deleteSpend(ownerId: owner, id: entry.id);

        expect(await transactions.watchMonthlyPnl(ledger).first, isEmpty);
      });

      test("does not count another owner's months", () async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');

        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: salary.id,
          amountScaled: 5000,
          occurredAt: DateTime.utc(2026, 7, 10),
        );

        expect(await transactions.watchMonthlyPnl('user-2').first, isEmpty);
      });
    });

    group('net total for one month', () {
      Future<Category> categoryOf(CategoryKind kind, String name) =>
          categories.createCategory(
            NewCategory(name: name, colorArgb: 1, iconKey: 'x', kind: kind),
            ownerId: owner,
            ledgerId: ledger,
          );

      /// 3000 in and 1000 out in March, 400 out in April.
      Future<void> seedTwoMonths() async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');
        final rent = await categoryOf(CategoryKind.expense, 'Rent');

        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: salary.id,
          amountScaled: 300000,
          occurredAt: DateTime.utc(2026, 3, 5),
        );
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: rent.id,
          amountScaled: 100000,
          occurredAt: DateTime.utc(2026, 3, 28),
        );
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: rent.id,
          amountScaled: 40000,
          occurredAt: DateTime.utc(2026, 4, 2),
        );
      }

      test('counts only what that month came to', () async {
        await seedTwoMonths();

        expect(
          await transactions
              .watchNetTotal(ledger, month: const CalendarMonth(2026, 3))
              .first,
          200000,
        );
        expect(
          await transactions
              .watchNetTotal(ledger, month: const CalendarMonth(2026, 4))
              .first,
          -40000,
        );
      });

      test('agrees with that month row in the monthly P&L', () async {
        await seedTwoMonths();

        final months = await transactions.watchMonthlyPnl(ledger).first;

        for (final month in months) {
          expect(
            await transactions
                .watchNetTotal(
                  ledger,
                  month: CalendarMonth(month.year, month.month),
                )
                .first,
            month.netScaled,
          );
        }
      });

      test('is zero for a month with nothing in it', () async {
        await seedTwoMonths();

        expect(
          await transactions
              .watchNetTotal(ledger, month: const CalendarMonth(2026, 2))
              .first,
          0,
        );
      });

      test('sums the whole ledger with no month asked for', () async {
        await seedTwoMonths();

        expect(await transactions.watchNetTotal(ledger).first, 160000);
      });
    });

    group('entries for one month', () {
      late Category groceries;
      late Category rent;

      /// 1250 in March and 500 in April against groceries, 100000 in March
      /// against rent.
      Future<void> seedTwoMonths() async {
        groceries = await newCategory();
        rent = await categories.createCategory(
          const NewCategory(name: 'Rent', colorArgb: 2, iconKey: 'home'),
          ownerId: owner,
          ledgerId: ledger,
        );

        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: groceries.id,
          amountScaled: 1250,
          occurredAt: DateTime.utc(2026, 3, 14),
        );
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: rent.id,
          amountScaled: 100000,
          occurredAt: DateTime.utc(2026, 3, 28),
        );
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: groceries.id,
          amountScaled: 500,
          occurredAt: DateTime.utc(2026, 4, 2),
        );
      }

      test('the whole ledger lists only that month', () async {
        await seedTwoMonths();

        final march = await transactions
            .watchAllEntries(
              ledgerId: ledger,
              viewerId: owner,
              month: const CalendarMonth(2026, 3),
            )
            .first;

        expect(march.map((e) => e.entry.amountScaled), [-100000, -1250]);
      });

      test("the entries listed add up to that month's net total", () async {
        await seedTwoMonths();

        const month = CalendarMonth(2026, 3);
        final entries = await transactions
            .watchAllEntries(ledgerId: ledger, viewerId: owner, month: month)
            .first;

        // The sheet adds its own rows up for the figure in its header, so the
        // two figures disagreeing would be visible on screen.
        expect(
          entries.fold(0, (sum, e) => sum + e.entry.amountScaled),
          await transactions.watchNetTotal(ledger, month: month).first,
        );
      });

      test('a category lists only that month', () async {
        await seedTwoMonths();

        final march = await transactions
            .watchCategoryHistory(
              ledgerId: ledger,
              viewerId: owner,
              categoryId: groceries.id,
              month: const CalendarMonth(2026, 3),
            )
            .first;

        expect(march.map((e) => e.amountScaled), [-1250]);
      });

      test('a month with nothing booked lists nothing', () async {
        await seedTwoMonths();

        expect(
          await transactions
              .watchAllEntries(
                ledgerId: ledger,
                viewerId: owner,
                month: const CalendarMonth(2026, 2),
              )
              .first,
          isEmpty,
        );
      });

      test('the months are UTC months, as the totals are', () async {
        groceries = await newCategory();

        // Half an hour into April in UTC, which is where it is stored and so
        // where it is counted — a reader an hour behind sees a March evening.
        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: groceries.id,
          amountScaled: 1250,
          occurredAt: DateTime.utc(2026, 4, 1, 0, 30),
        );

        Future<int> entriesIn(CalendarMonth month) async {
          final entries = await transactions
              .watchAllEntries(ledgerId: ledger, viewerId: owner, month: month)
              .first;

          return entries.length;
        }

        expect(await entriesIn(const CalendarMonth(2026, 3)), 0);
        expect(await entriesIn(const CalendarMonth(2026, 4)), 1);
      });

      test('no month asked for lists the whole ledger', () async {
        await seedTwoMonths();

        final all = await transactions
            .watchAllEntries(ledgerId: ledger, viewerId: owner)
            .first;

        expect(all, hasLength(3));
      });
    });

    group('a family account', () {
      /// Puts [userId] in [ledger] under [name], which is what gives their
      /// entries a label on the other partner's device.
      Future<void> joinLedger(String userId, String name) => db
          .into(db.ledgerMembers)
          .insert(
            LedgerMembersCompanion.insert(
              id: Value(ledgerMemberId(ledgerId: ledger, userId: userId)),
              ledgerId: ledger,
              userId: userId,
              role: LedgerRole.member.storage,
              displayName: Value(name),
            ),
          );

      /// One shared category with an entry from each partner.
      Future<Category> seedBoth() async {
        final category = await newCategory();

        await transactions.recordSpend(
          ownerId: owner,
          ledgerId: ledger,
          categoryId: category.id,
          amountScaled: 1000,
        );
        await transactions.recordSpend(
          ownerId: partner,
          ledgerId: ledger,
          categoryId: category.id,
          amountScaled: 2500,
        );

        return category;
      }

      test('adds both partners into the category total', () async {
        await seedBoth();

        final spend = await categories
            .watchCategorySpend(ledger, CategoryKind.expense)
            .first;

        // The whole point of the feature: one tile, one figure, both people.
        expect(spend.single.totalScaled, -3500);
      });

      test('adds both partners into the net total', () async {
        await seedBoth();

        expect(await transactions.watchNetTotal(ledger).first, -3500);
      });

      test('lists both partners in the all-transactions list', () async {
        await seedBoth();

        final entries = await transactions
            .watchAllEntries(ledgerId: ledger, viewerId: owner)
            .first;

        expect(entries.map((e) => e.entry.amountScaled), [-2500, -1000]);
      });

      test("labels a partner's entry and leaves your own unlabelled", () async {
        await joinLedger(partner, 'kate@example.com');
        await seedBoth();

        final entries = await transactions
            .watchAllEntries(ledgerId: ledger, viewerId: owner)
            .first;

        final theirs = entries.firstWhere((e) => e.entry.amountScaled == -2500);
        final mine = entries.firstWhere((e) => e.entry.amountScaled == -1000);

        // Shortened to the part before the @: the domain is the same for
        // everyone in most households, so it is the half that says nothing.
        expect(theirs.entry.authorName, 'kate');
        expect(theirs.entry.isOwn, isFalse);

        expect(mine.entry.authorName, isNull);
        expect(mine.entry.isOwn, isTrue);
      });

      test('labels a partner who has no name yet', () async {
        // Their device writes the name; until it has, there is still a row to
        // tell apart from the reader's own.
        await seedBoth();

        final entries = await transactions
            .watchAllEntries(ledgerId: ledger, viewerId: owner)
            .first;
        final theirs = entries.firstWhere((e) => e.entry.amountScaled == -2500);

        expect(theirs.entry.authorName, 'Partner');
        expect(theirs.entry.isOwn, isFalse);
      });

      test('labels a partner in the category history too', () async {
        await joinLedger(partner, 'kate@example.com');
        final category = await seedBoth();

        final history = await transactions
            .watchCategoryHistory(
              ledgerId: ledger,
              viewerId: owner,
              categoryId: category.id,
            )
            .first;

        expect(
          history.map((e) => e.authorName),
          ['kate', null],
          reason: "newest first, and the reader's own is not labelled",
        );
      });

      test("refuses to change a partner's entry", () async {
        await seedBoth();

        final entries = await transactions
            .watchAllEntries(ledgerId: ledger, viewerId: owner)
            .first;
        final theirs = entries
            .firstWhere((e) => e.entry.amountScaled == -2500)
            .entry;

        // Read together, written separately. The Postgres policy says the same,
        // and this is what keeps the app from offering what it would refuse.
        await expectLater(
          transactions.updateSpend(
            ownerId: owner,
            id: theirs.id,
            amountScaled: 1,
          ),
          throwsStateError,
        );
        await expectLater(
          transactions.deleteSpend(ownerId: owner, id: theirs.id),
          throwsStateError,
        );
      });

      test('books both partners against one shared account', () async {
        await seedBoth();

        final accounts = await db.select(db.accounts).get();
        // Not one Cash each: every entry joins through `account_id`, and two
        // accounts by the same name would make that join depend on who recorded
        // the entry.
        expect(accounts, hasLength(1));
      });

      test('shows nothing of another book', () async {
        await seedBoth();

        expect(
          await transactions
              .watchAllEntries(ledgerId: otherLedger, viewerId: owner)
              .first,
          isEmpty,
        );
        expect(await transactions.watchNetTotal(otherLedger).first, 0);
      });

      test('refuses to book against a category from another book', () async {
        final category = await categories.createCategory(
          const NewCategory(name: 'Theirs', colorArgb: 1, iconKey: 'x'),
          ownerId: owner,
          ledgerId: otherLedger,
        );

        await expectLater(
          transactions.recordSpend(
            ownerId: owner,
            ledgerId: ledger,
            categoryId: category.id,
            amountScaled: 1000,
          ),
          throwsStateError,
        );
      });
    });
  });
}
