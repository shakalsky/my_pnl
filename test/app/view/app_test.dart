import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/app/app.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/app_update/domain/entities/app_version.dart';
import 'package:my_pnl/features/app_update/domain/entities/update_requirement.dart';
import 'package:my_pnl/features/app_update/presentation/pages/required_update_page.dart';
import 'package:my_pnl/features/auth/domain/entities/auth_user.dart';
import 'package:my_pnl/features/auth/presentation/pages/sign_in_page.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/base_currency_sheet.dart';
import 'package:my_pnl/features/spending/presentation/pages/income_overview_page.dart';
import 'package:my_pnl/features/spending/presentation/pages/spending_overview_page.dart';

import '../../helpers/helpers.dart';

/// One the reader added, quoted against the dollar.
const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000,
);

void main() {
  group('App', () {
    late AppDatabase database;
    late FakeCategoryRepository spending;
    late FakeCurrencyRepository currencies;
    late FakeDebtRepository debts;
    late FakeGoalRepository goals;
    late FakeLedgerRepository ledgers;
    late FakeAppUpdateRepository updates;
    late FakeBaseCurrencyStore baseCurrency;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
      baseCurrency = FakeBaseCurrencyStore();
      spending = FakeCategoryRepository();
      currencies = FakeCurrencyRepository();
      debts = FakeDebtRepository();
      goals = FakeGoalRepository();
      ledgers = FakeLedgerRepository();
      updates = FakeAppUpdateRepository();
    });

    tearDown(() async {
      await baseCurrency.close();
      // The base is one value for the whole process, and this is the shell that
      // applies it. Put back, or the next test opens in whatever was chosen here.
      setActiveBaseCurrency(BaseCurrency.usd);
      await updates.close();
      await ledgers.close();
      await goals.close();
      await debts.close();
      await currencies.close();
      await spending.close();
      await database.close();
    });

    Future<void> pumpAppWith(
      WidgetTester tester,
      FakeAuthRepository auth,
    ) async {
      await tester.pumpWidget(
        App(
          database: database,
          appUpdateRepository: updates,
          authRepository: auth,
          baseCurrencyStore: baseCurrency,
          categoryRepository: spending,
          currencyRepository: currencies,
          displayCurrencyStore: FakeDisplayCurrencyStore(),
          debtRepository: debts,
          goalRepository: goals,
          ledgerRepository: ledgers,
          overrunSettingsStore: FakeOverrunSettingsStore(),
          transactionRepository: spending,
          syncRepository: FakeSyncRepository(),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('sends a signed-out user to sign-in', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);

      expect(find.byType(SignInPage), findsOneWidget);
      expect(find.byType(SpendingOverviewPage), findsNothing);
    });

    testWidgets('opens the overview for a restored session', (tester) async {
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
      );
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);

      expect(find.byType(SpendingOverviewPage), findsOneWidget);
      expect(find.byType(SignInPage), findsNothing);
    });

    testWidgets('redirects to the overview once signed in', (tester) async {
      final auth = FakeAuthRepository();
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);
      expect(find.byType(SignInPage), findsOneWidget);

      await auth.signIn(email: 'a@b.com', password: 'secret1');
      await tester.pumpAndSettle();

      expect(find.byType(SpendingOverviewPage), findsOneWidget);
    });

    group('the update gate', () {
      /// Older than the running build the fake reports.
      const needsNewer = UpdateRequirement(
        minVersion: AppVersion(major: 9, minor: 0, patch: 0),
      );

      testWidgets('holds a signed-in user on the update screen', (
        tester,
      ) async {
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        expect(find.byType(RequiredUpdatePage), findsOneWidget);
        expect(find.byType(SpendingOverviewPage), findsNothing);
      });

      testWidgets('holds a signed-out user there as well', (tester) async {
        // Checked before auth on purpose: a build the backend has stopped
        // supporting has no business signing anyone in.
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository();
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        expect(find.byType(RequiredUpdatePage), findsOneWidget);
        expect(find.byType(SignInPage), findsNothing);
      });

      testWidgets('lets the user in when a check clears the requirement', (
        tester,
      ) async {
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);
        expect(find.byType(RequiredUpdatePage), findsOneWidget);

        updates.require(null);
        await tester.pumpAndSettle();

        expect(find.byType(SpendingOverviewPage), findsOneWidget);
        expect(find.byType(RequiredUpdatePage), findsNothing);
      });

      testWidgets('sends a blocked signed-out user on to sign-in', (
        tester,
      ) async {
        updates = FakeAppUpdateRepository(requirement: needsNewer);
        final auth = FakeAuthRepository();
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        updates.require(null);
        await tester.pumpAndSettle();

        // The auth gate takes over once the update gate lets go.
        expect(find.byType(SignInPage), findsOneWidget);
      });

      testWidgets('stays out of the way when nothing is required', (
        tester,
      ) async {
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);

        expect(find.byType(SpendingOverviewPage), findsOneWidget);
      });
    });

    group('the overview pager', () {
      /// A signed-in session sitting on the overview.
      Future<void> openOverview(WidgetTester tester) async {
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);
      }

      /// Both pages stay built — they are peers in a pager, not one on top of
      /// the other — so which is showing is a question of where they sit, not
      /// of what exists. The one off screen is offstage, hence `skipOffstage`.
      void expectShowing(WidgetTester tester, Type page) {
        for (final type in [SpendingOverviewPage, IncomeOverviewPage]) {
          final finder = find.byType(type, skipOffstage: false);
          expect(finder, findsOneWidget, reason: '$type is built either way');
          expect(
            tester.getTopLeft(finder).dx,
            type == page ? 0 : isNot(0),
            reason:
                '$type ${type == page ? 'should' : 'should not'} be showing',
          );
        }
      }

      /// A flick across the middle of whichever page is showing.
      Future<void> flick(WidgetTester tester, double dx) async {
        await tester.fling(find.byType(PageView), Offset(dx, 0), 1000);
        await tester.pumpAndSettle();
      }

      testWidgets('opens on spending, with income alongside', (tester) async {
        await openOverview(tester);

        expectShowing(tester, SpendingOverviewPage);
      });

      testWidgets('swiping right shows income', (tester) async {
        await openOverview(tester);

        await flick(tester, 300);

        expectShowing(tester, IncomeOverviewPage);
      });

      testWidgets('swiping left again shows spending', (tester) async {
        await openOverview(tester);

        await flick(tester, 300);
        expectShowing(tester, IncomeOverviewPage);

        await flick(tester, -300);

        expectShowing(tester, SpendingOverviewPage);
      });

      testWidgets('neither page is pushed over the other', (tester) async {
        await openOverview(tester);
        await flick(tester, 300);

        // Nothing to pop: income is beside spending rather than over it, so
        // both are the one route and there is no back stack to unwind.
        expect(find.byTooltip('Back'), findsNothing);
        expect(
          Navigator.of(tester.element(find.byType(PageView))).canPop(),
          isFalse,
        );
      });

      testWidgets('income carries no app bar of its own', (tester) async {
        await openOverview(tester);
        await flick(tester, 300);
        expectShowing(tester, IncomeOverviewPage);

        // Swiping is the way back: income is a page of the pager rather than
        // a screen with its own chrome, so there is no arrow to press.
        expect(find.byTooltip('Spending'), findsNothing);
        expect(find.byType(AppBar), findsNothing);
      });
    });

    group('the base currency', () {
      /// A signed-in session sitting on the overview, where a total is showing.
      Future<void> openOverview(WidgetTester tester) async {
        final auth = FakeAuthRepository(
          initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
        );
        addTearDown(auth.close);

        await pumpAppWith(tester, auth);
      }

      testWidgets('labels figures with the currency stored for the device', (
        tester,
      ) async {
        baseCurrency = FakeBaseCurrencyStore(
          initial: const BaseCurrency(ticker: 'PLN', symbol: 'zł'),
        );

        await openOverview(tester);

        // Applied before anything was drawn, rather than in dollars first.
        expect(find.text('zł0.00'), findsWidgets);
        expect(find.text(r'$0.00'), findsNothing);
      });

      testWidgets('relabels what is on screen when the choice changes', (
        tester,
      ) async {
        await openOverview(tester);
        expect(find.text(r'$0.00'), findsWidgets);

        // What the sheet does, once the reader has agreed to it.
        await baseCurrency.write(
          const BaseCurrency(ticker: 'PLN', symbol: 'zł'),
        );
        await tester.pumpAndSettle();

        expect(find.text('zł0.00'), findsWidgets);
        expect(find.text(r'$0.00'), findsNothing);
      });

      testWidgets('is changed from the currencies sheet, rates and all', (
        tester,
      ) async {
        currencies = FakeCurrencyRepository(initial: const [_euro]);

        await openOverview(tester);
        await tester.tap(find.byTooltip('Currencies'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Base currency'));
        await tester.pumpAndSettle();

        // First on offer, as one the reader added.
        await tester.tap(
          find.descendant(
            of: find.byType(BaseCurrencySheet),
            matching: find.widgetWithText(ListTile, 'EUR'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Switch to EUR'));
        await tester.pumpAndSettle();

        expect(baseCurrency.writes, [
          const BaseCurrency(ticker: 'EUR', symbol: '€'),
        ]);
        expect(
          await currencies.watchCurrencies().first,
          isEmpty,
          reason: 'their rate was quoted against the dollar',
        );
        // Both sheets are gone and the figures behind them read in the euro.
        expect(find.byType(BaseCurrencySheet), findsNothing);
        expect(find.text('€0.00'), findsWidgets);
      });
    });

    testWidgets('returns to sign-in on sign-out', (tester) async {
      final auth = FakeAuthRepository(
        initialUser: const AuthUser(id: 'user-1', email: 'a@b.com'),
      );
      addTearDown(auth.close);

      await pumpAppWith(tester, auth);
      expect(find.byType(SpendingOverviewPage), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();

      expect(find.byType(SignInPage), findsOneWidget);
    });
  });
}
