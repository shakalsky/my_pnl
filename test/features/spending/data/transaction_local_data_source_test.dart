import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/data/datasources/transaction_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';

void main() {
  group('TransactionLocalDataSource', () {
    late AppDatabase db;
    late TransactionLocalDataSource transactions;
    late CategoryLocalDataSource categories;

    const owner = 'user-1';

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
      owner,
    );

    test('creates the default account on first use, then reuses it', () async {
      final category = await newCategory();

      await transactions.recordSpend(
        ownerId: owner,
        categoryId: category.id,
        amountScaled: 1250,
      );
      await transactions.recordSpend(
        ownerId: owner,
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
        categoryId: category.id,
        amountScaled: 1250,
      );
      await transactions.recordSpend(
        ownerId: owner,
        categoryId: category.id,
        amountScaled: 500,
      );

      final spend = await categories
          .watchCategorySpend(owner, CategoryKind.expense)
          .first;
      expect(spend.single.totalScaled, -1750, reason: 'spending is negative');
    });

    test('lists a category history newest first', () async {
      final category = await newCategory();

      await transactions.recordSpend(
        ownerId: owner,
        categoryId: category.id,
        amountScaled: 1250,
        occurredAt: DateTime.utc(2026, 3, 10),
      );
      await transactions.recordSpend(
        ownerId: owner,
        categoryId: category.id,
        amountScaled: 500,
        occurredAt: DateTime.utc(2026, 3, 14),
      );

      final history = await transactions
          .watchCategoryHistory(ownerId: owner, categoryId: category.id)
          .first;

      expect(history.map((e) => e.amountScaled), [-500, -1250]);
      expect(history.first.occurredAt, DateTime.utc(2026, 3, 14));
    });

    test('history excludes another category and soft-deleted rows', () async {
      final groceries = await newCategory();
      final dining = await categories.createCategory(
        const NewCategory(name: 'Dining', colorArgb: 2, iconKey: 'dining'),
        owner,
      );

      await transactions.recordSpend(
        ownerId: owner,
        categoryId: groceries.id,
        amountScaled: 1250,
      );
      await transactions.recordSpend(
        ownerId: owner,
        categoryId: dining.id,
        amountScaled: 999,
      );

      final history = await transactions
          .watchCategoryHistory(ownerId: owner, categoryId: groceries.id)
          .first;

      expect(history.map((e) => e.amountScaled), [-1250]);
    });

    test('updating changes the amount and the category total', () async {
      final category = await newCategory();
      await transactions.recordSpend(
        ownerId: owner,
        categoryId: category.id,
        amountScaled: 1250,
      );
      final entry =
          (await transactions
                  .watchCategoryHistory(ownerId: owner, categoryId: category.id)
                  .first)
              .single;

      await transactions.updateSpend(
        ownerId: owner,
        id: entry.id,
        amountScaled: 999,
      );

      final spend = await categories
          .watchCategorySpend(owner, CategoryKind.expense)
          .first;
      expect(spend.single.totalScaled, -999);
    });

    test('deleting tombstones the row rather than removing it', () async {
      final category = await newCategory();
      await transactions.recordSpend(
        ownerId: owner,
        categoryId: category.id,
        amountScaled: 1250,
      );
      final entry =
          (await transactions
                  .watchCategoryHistory(ownerId: owner, categoryId: category.id)
                  .first)
              .single;

      await transactions.deleteSpend(ownerId: owner, id: entry.id);

      // Gone from every read...
      final history = await transactions
          .watchCategoryHistory(ownerId: owner, categoryId: category.id)
          .first;
      expect(history, isEmpty);
      final spend = await categories
          .watchCategorySpend(owner, CategoryKind.expense)
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
        categoryId: category.id,
        amountScaled: 1250,
      );
      final entry =
          (await transactions
                  .watchCategoryHistory(ownerId: owner, categoryId: category.id)
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
            owner,
          );

      test('groups income and spending by calendar month', () async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');
        final rent = await categoryOf(CategoryKind.expense, 'Rent');

        // March: 3000 in, 1000 out — up 2000.
        await transactions.recordSpend(
          ownerId: owner,
          categoryId: salary.id,
          amountScaled: 300000,
          occurredAt: DateTime.utc(2026, 3, 5),
        );
        await transactions.recordSpend(
          ownerId: owner,
          categoryId: rent.id,
          amountScaled: 100000,
          occurredAt: DateTime.utc(2026, 3, 28),
        );
        // April: nothing in, 400 out — down 400.
        await transactions.recordSpend(
          ownerId: owner,
          categoryId: rent.id,
          amountScaled: 40000,
          occurredAt: DateTime.utc(2026, 4, 2),
        );

        final months = await transactions.watchMonthlyPnl(owner).first;

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
          categoryId: salary.id,
          amountScaled: 100,
          occurredAt: DateTime.utc(2026),
        );
        await transactions.recordSpend(
          ownerId: owner,
          categoryId: salary.id,
          amountScaled: 100,
          occurredAt: DateTime.utc(2026, 6),
        );

        final months = await transactions.watchMonthlyPnl(owner).first;

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
          categoryId: salary.id,
          amountScaled: 5000,
          occurredAt: DateTime.utc(2026, 7, 10),
        );
        final entry =
            (await transactions
                    .watchCategoryHistory(
                      ownerId: owner,
                      categoryId: salary.id,
                    )
                    .first)
                .single;

        await transactions.deleteSpend(ownerId: owner, id: entry.id);

        expect(await transactions.watchMonthlyPnl(owner).first, isEmpty);
      });

      test("does not count another owner's months", () async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');

        await transactions.recordSpend(
          ownerId: owner,
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
            owner,
          );

      /// 3000 in and 1000 out in March, 400 out in April.
      Future<void> seedTwoMonths() async {
        final salary = await categoryOf(CategoryKind.income, 'Salary');
        final rent = await categoryOf(CategoryKind.expense, 'Rent');

        await transactions.recordSpend(
          ownerId: owner,
          categoryId: salary.id,
          amountScaled: 300000,
          occurredAt: DateTime.utc(2026, 3, 5),
        );
        await transactions.recordSpend(
          ownerId: owner,
          categoryId: rent.id,
          amountScaled: 100000,
          occurredAt: DateTime.utc(2026, 3, 28),
        );
        await transactions.recordSpend(
          ownerId: owner,
          categoryId: rent.id,
          amountScaled: 40000,
          occurredAt: DateTime.utc(2026, 4, 2),
        );
      }

      test('counts only what that month came to', () async {
        await seedTwoMonths();

        expect(
          await transactions
              .watchNetTotal(owner, month: const CalendarMonth(2026, 3))
              .first,
          200000,
        );
        expect(
          await transactions
              .watchNetTotal(owner, month: const CalendarMonth(2026, 4))
              .first,
          -40000,
        );
      });

      test('agrees with that month row in the monthly P&L', () async {
        await seedTwoMonths();

        final months = await transactions.watchMonthlyPnl(owner).first;

        for (final month in months) {
          expect(
            await transactions
                .watchNetTotal(
                  owner,
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
              .watchNetTotal(owner, month: const CalendarMonth(2026, 2))
              .first,
          0,
        );
      });

      test('sums the whole ledger with no month asked for', () async {
        await seedTwoMonths();

        expect(await transactions.watchNetTotal(owner).first, 160000);
      });
    });
  });
}
