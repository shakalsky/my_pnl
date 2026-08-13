import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/currencies/data/datasources/currency_local_data_source.dart';
import 'package:my_pnl/features/currencies/data/repositories/currency_repository_impl.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/debts/data/datasources/debt_local_data_source.dart';
import 'package:my_pnl/features/debts/data/repositories/debt_repository_impl.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/goals/data/datasources/goal_local_data_source.dart';
import 'package:my_pnl/features/goals/data/repositories/goal_repository_impl.dart';
import 'package:my_pnl/features/spending/data/datasources/category_local_data_source.dart';
import 'package:my_pnl/features/spending/data/datasources/transaction_local_data_source.dart';
import 'package:my_pnl/features/spending/data/repositories/category_repository_impl.dart';
import 'package:my_pnl/features/spending/data/repositories/transaction_repository_impl.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';

/// A [SessionOwner] with nothing to configure.
class _Owner implements SessionOwner {
  @override
  String get id => 'user-1';

  @override
  String? get label => 'me@example.com';
}

void main() {
  /// Switching books has to reach whatever is already on screen.
  ///
  /// It cannot be done from the widget tree: the router keeps its Navigator
  /// behind a `GlobalKey`, so rebuilding the app shell preserves the pages and
  /// the blocs beneath them — subscriptions included. Every read is therefore
  /// built over `LedgerScope.changes`, and these are the tests that say so.
  ///
  /// Written against real repositories over a real database rather than fakes,
  /// because the thing under test is the wiring between the two.
  group('a switch reloads what is already being read', () {
    late AppDatabase db;
    late ActiveLedger active;
    late _Owner owner;

    late CategoryRepositoryImpl categories;
    late TransactionRepositoryImpl transactions;
    late CurrencyRepositoryImpl currencies;
    late DebtRepositoryImpl debts;
    late GoalRepositoryImpl goals;

    const personal = 'ledger-personal';
    const family = 'ledger-family';

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      active = ActiveLedger(personal);
      owner = _Owner();

      categories = CategoryRepositoryImpl(
        localDataSource: CategoryLocalDataSource(db),
        sessionOwner: owner,
        ledgerScope: active,
      );
      transactions = TransactionRepositoryImpl(
        localDataSource: TransactionLocalDataSource(db),
        sessionOwner: owner,
        ledgerScope: active,
      );
      currencies = CurrencyRepositoryImpl(
        localDataSource: CurrencyLocalDataSource(db),
        sessionOwner: owner,
        ledgerScope: active,
      );
      debts = DebtRepositoryImpl(
        localDataSource: DebtLocalDataSource(db),
        sessionOwner: owner,
        ledgerScope: active,
      );
      goals = GoalRepositoryImpl(
        localDataSource: GoalLocalDataSource(db),
        sessionOwner: owner,
        ledgerScope: active,
      );
    });

    tearDown(() async {
      await active.close();
      await db.close();
    });

    /// Everything [stream] emits while the reader walks through [switches].
    ///
    /// Each step is given time to settle before the next, which is what a reader
    /// tapping a switcher does. Without the pause the switch would land before
    /// the first query returned, and `switchLatest` would correctly drop that
    /// query rather than emit a book the reader had already left.
    Future<List<T>> readThrough<T>(
      Stream<T> stream,
      List<String> switches,
    ) async {
      final seen = <T>[];
      final subscription = stream.listen(seen.add);
      await pumpEventQueue();

      for (final ledgerId in switches) {
        active.switchTo(ledgerId);
        await pumpEventQueue();
      }

      await subscription.cancel();
      return seen;
    }

    /// A category in [ledgerId] with one entry booked against it.
    Future<Category> seedCategory({
      required String ledgerId,
      required String name,
      required int amountScaled,
    }) async {
      final source = CategoryLocalDataSource(db);
      final category = await source.createCategory(
        NewCategory(name: name, colorArgb: 1, iconKey: 'x'),
        ownerId: owner.id,
        ledgerId: ledgerId,
      );

      final account = await db
          .into(db.accounts)
          .insertReturning(
            AccountsCompanion.insert(
              ownerId: owner.id,
              ledgerId: Value(ledgerId),
              name: 'Cash',
              currency: 'USD',
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            TransactionsCompanion.insert(
              ownerId: owner.id,
              ledgerId: Value(ledgerId),
              accountId: account.id,
              categoryId: Value(category.id),
              side: TradeSide.buy,
              amountScaled: -amountScaled,
              currency: 'USD',
              executedAt: DateTime.utc(2026, 3, 14),
            ),
          );

      return category;
    }

    test('the category grid the overview is built from', () async {
      await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );
      await seedCategory(
        ledgerId: family,
        name: 'Ours',
        amountScaled: 4000,
      );

      // Switched while the subscription is live, exactly as the switcher does it.
      final seen = await readThrough(
        categories
            .watchCategorySpend(CategoryKind.expense)
            .map((spend) => spend.map((e) => e.category.name).toList()),
        [family],
      );

      expect(seen, [
        ['Mine'],
        ['Ours'],
      ]);
    });

    test('the total in the wheel', () async {
      await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );
      await seedCategory(
        ledgerId: family,
        name: 'Ours',
        amountScaled: 4000,
      );

      final seen = await readThrough(transactions.watchNetTotal(), [family]);

      expect(seen, [-1000, -4000]);
    });

    test('the all-transactions list', () async {
      await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );
      await seedCategory(
        ledgerId: family,
        name: 'Ours',
        amountScaled: 4000,
      );

      final seen = await readThrough(
        transactions.watchAllEntries().map(
          (entries) => entries.map((e) => e.entry.amountScaled).toList(),
        ),
        [family],
      );

      expect(seen, [
        [-1000],
        [-4000],
      ]);
    });

    test('the month-by-month figures', () async {
      await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );
      await seedCategory(
        ledgerId: family,
        name: 'Ours',
        amountScaled: 4000,
      );

      final seen = await readThrough(
        transactions.watchMonthlyPnl().map(
          (months) => months.map((m) => m.netScaled).toList(),
        ),
        [family],
      );

      expect(seen, [
        [-1000],
        [-4000],
      ]);
    });

    test('a category history that is open', () async {
      final mine = await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );

      // The category belongs to the book being left, so the history empties.
      // Better than showing the amounts of a book the reader has closed.
      final seen = await readThrough(
        transactions.watchCategoryHistory(mine.id).map((e) => e.length),
        [family],
      );

      expect(seen, [1, 0]);
    });

    test('the debts page', () async {
      final source = DebtLocalDataSource(db);
      await source.createDebt(
        const NewDebt(
          counterparty: 'Alex',
          direction: DebtDirection.owedToMe,
          amountScaled: 2500,
        ),
        ownerId: owner.id,
        ledgerId: personal,
      );
      await source.createDebt(
        const NewDebt(
          counterparty: 'Landlord',
          direction: DebtDirection.owedByMe,
          amountScaled: 90000,
        ),
        ownerId: owner.id,
        ledgerId: family,
      );

      final seen = await readThrough(
        debts.watchDebts().map(
          (all) => all.map((debt) => debt.counterparty).toList(),
        ),
        [family],
      );

      expect(seen, [
        ['Alex'],
        ['Landlord'],
      ]);
    });

    test('the goal', () async {
      final source = GoalLocalDataSource(db);
      await source.saveGoal(
        ownerId: owner.id,
        ledgerId: personal,
        targetAmountScaled: 500000,
      );
      await source.saveGoal(
        ownerId: owner.id,
        ledgerId: family,
        targetAmountScaled: 900000,
      );

      final seen = await readThrough(
        goals.watchGoal().map((goal) => goal?.targetAmountScaled),
        [family],
      );

      expect(seen, [500000, 900000]);
    });

    test('the currencies every figure is converted through', () async {
      final source = CurrencyLocalDataSource(db);
      await source.createCurrency(
        const NewCurrency(ticker: 'EUR', exchangeRateScaled: 1080000),
        ownerId: owner.id,
        ledgerId: personal,
      );
      await source.createCurrency(
        const NewCurrency(ticker: 'GBP', exchangeRateScaled: 1250000),
        ownerId: owner.id,
        ledgerId: family,
      );

      final seen = await readThrough(
        currencies.watchCurrencies().map(
          (all) => all.map((currency) => currency.ticker).toList(),
        ),
        [family],
      );

      expect(seen, [
        ['EUR'],
        ['GBP'],
      ]);
    });

    test('switching back reads the first book again', () async {
      await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );
      await seedCategory(
        ledgerId: family,
        name: 'Ours',
        amountScaled: 4000,
      );

      final seen = await readThrough(transactions.watchNetTotal(), [
        family,
        personal,
      ]);

      expect(seen, [-1000, -4000, -1000]);
    });

    test('a switch to the book already open changes nothing', () async {
      await seedCategory(
        ledgerId: personal,
        name: 'Mine',
        amountScaled: 1000,
      );

      final seen = await readThrough(transactions.watchNetTotal(), [personal]);

      // No re-subscription, so no second identical value: a page that reloaded on
      // every no-op switch would flicker for nothing.
      expect(seen, [-1000]);
    });
  });
}
