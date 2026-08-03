import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
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
  });
}
