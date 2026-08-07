import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/base_currency_sheet.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_list_sheet.dart';

import '../../../../helpers/helpers.dart';

const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000,
);

const _zloty = Currency(
  id: 'currency-2',
  ticker: 'PLN',
  exchangeRateScaled: 250000,
);

/// One of the reader's own, which no catalogue offers.
const _gold = Currency(
  id: 'currency-3',
  ticker: 'GLD',
  icon: '🪙',
  exchangeRateScaled: 2400000000,
);

/// Scoped to the base currency sheet: the currencies sheet it opens over carries
/// some of the same labels.
///
/// Offstage widgets count. The list runs to thirty-odd currencies inside a modal
/// half the height of the screen, so most of what it offers is scrolled out of
/// view rather than absent.
Finder _inSheet(Finder finder) => find.descendant(
  of: find.byType(BaseCurrencySheet, skipOffstage: false),
  matching: finder,
  skipOffstage: false,
);

void main() {
  group('changing the base currency', () {
    late FakeCurrencyRepository repository;
    late FakeBaseCurrencyStore store;

    setUp(() {
      repository = FakeCurrencyRepository();
      store = FakeBaseCurrencyStore();
    });

    tearDown(() async {
      await repository.close();
      await store.close();
      // The base is one value for the whole process, and the app shell is what
      // normally applies a change. Put back so the next test opens in dollars.
      setActiveBaseCurrency(BaseCurrency.usd);
    });

    /// Opens the currencies sheet, since the base is changed from within it.
    Future<void> openCurrencies(WidgetTester tester) async {
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CurrencyListSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
        currencyRepository: repository,
        baseCurrencyStore: store,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    /// Opens the currencies sheet and the base currency sheet inside it.
    Future<void> openBaseCurrency(WidgetTester tester) async {
      await openCurrencies(tester);

      await tester.tap(find.text('Base currency'));
      await tester.pumpAndSettle();
    }

    /// Taps [ticker]'s row, scrolling the list down to it first.
    ///
    /// By ticker rather than by name, because the row for a currency the reader
    /// added carries theirs — the catalogue's entry for it is not offered twice.
    Future<void> chooseBase(WidgetTester tester, String ticker) async {
      final option = _inSheet(find.widgetWithText(ListTile, ticker));

      await tester.scrollUntilVisible(
        option,
        120,
        scrollable: find.descendant(
          of: find.byType(BaseCurrencySheet),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(option);
      await tester.pumpAndSettle();
    }

    testWidgets('the currencies sheet says what the base is', (tester) async {
      await openCurrencies(tester);

      expect(find.text('Everything is recorded in USD'), findsOneWidget);
    });

    testWidgets('offers the currencies to switch to, marking the base', (
      tester,
    ) async {
      await openBaseCurrency(tester);

      expect(_inSheet(find.text('US dollar')), findsOneWidget);
      expect(_inSheet(find.text('Euro')), findsOneWidget);
      expect(_inSheet(find.byIcon(Icons.check)), findsOneWidget);
    });

    testWidgets('offers a currency the reader added themselves', (
      tester,
    ) async {
      repository = FakeCurrencyRepository(initial: const [_gold]);
      await openBaseCurrency(tester);

      expect(_inSheet(find.text('GLD')), findsOneWidget);
      expect(_inSheet(find.text('One you added')), findsOneWidget);
      // The sign it is already shown with, rather than its ticker again.
      expect(_inSheet(find.text('🪙')), findsOneWidget);
    });

    testWidgets('names an added currency once when it is in the catalogue', (
      tester,
    ) async {
      repository = FakeCurrencyRepository(initial: const [_zloty]);
      await openBaseCurrency(tester);

      // Once, rather than once as their own and once as the catalogue's.
      expect(_inSheet(find.widgetWithText(ListTile, 'PLN')), findsOneWidget);
    });

    testWidgets('says which added currencies a switch would delete', (
      tester,
    ) async {
      repository = FakeCurrencyRepository(initial: const [_euro, _zloty]);
      await openBaseCurrency(tester);

      await chooseBase(tester, 'GBP');

      expect(find.text('Switch to GBP?'), findsOneWidget);
      expect(
        find.textContaining('EUR and PLN will be deleted'),
        findsOneWidget,
      );
      expect(find.textContaining('keep the numbers'), findsOneWidget);
    });

    testWidgets('says that the chosen currency leaves the list too', (
      tester,
    ) async {
      repository = FakeCurrencyRepository(initial: const [_euro, _zloty]);
      await openBaseCurrency(tester);

      await chooseBase(tester, 'EUR');

      expect(find.textContaining('PLN will be deleted'), findsOneWidget);
      expect(
        find.textContaining('EUR leaves your added currencies as well'),
        findsOneWidget,
      );
    });

    testWidgets('changes the base and deletes the added currencies', (
      tester,
    ) async {
      repository = FakeCurrencyRepository(initial: const [_euro, _zloty]);
      await openBaseCurrency(tester);

      await chooseBase(tester, 'EUR');
      await tester.tap(find.widgetWithText(FilledButton, 'Switch to EUR'));
      await tester.pumpAndSettle();

      expect(store.writes, [const BaseCurrency(ticker: 'EUR', symbol: '€')]);
      expect(await repository.watchCurrencies().first, isEmpty);
      // Both sheets close: every label in them names the base that has just been
      // replaced.
      expect(find.text('Base currency'), findsNothing);
      expect(find.text('Currencies'), findsNothing);
    });

    testWidgets('keeps everything when the reader cancels', (tester) async {
      repository = FakeCurrencyRepository(initial: const [_euro]);
      await openBaseCurrency(tester);

      await chooseBase(tester, 'GBP');
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(store.writes, isEmpty);
      expect(await repository.watchCurrencies().first, [_euro]);
      expect(find.byType(BaseCurrencySheet), findsOneWidget);
    });

    testWidgets('the base in force cannot be chosen again', (tester) async {
      await openBaseCurrency(tester);

      await chooseBase(tester, 'USD');

      expect(find.text('Switch to USD?'), findsNothing);
      expect(store.writes, isEmpty);
    });

    testWidgets('says so when the change fails', (tester) async {
      repository = FakeCurrencyRepository(initial: const [_euro]);
      await openBaseCurrency(tester);
      repository.writeError = Exception('nope');

      await chooseBase(tester, 'GBP');
      await tester.tap(find.widgetWithText(FilledButton, 'Switch to GBP'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not change the base currency'),
        findsOneWidget,
      );
      expect(store.writes, isEmpty);
      expect(
        find.byType(BaseCurrencySheet),
        findsOneWidget,
        reason: 'the sheet stays open so the choice can be made again',
      );
    });

    testWidgets('opens on a base the reader has already changed', (
      tester,
    ) async {
      store = FakeBaseCurrencyStore(
        initial: const BaseCurrency(ticker: 'PLN', symbol: 'zł'),
      );
      await openBaseCurrency(tester);

      // The sheet reads the stored base rather than the one this run started on.
      final marked = tester.widget<ListTile>(
        find.ancestor(
          of: find.byIcon(Icons.check, skipOffstage: false),
          matching: find.byType(ListTile, skipOffstage: false),
        ),
      );
      expect((marked.title! as Text).data, 'PLN');
    });
  });
}
