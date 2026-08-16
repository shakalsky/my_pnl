
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/presentation/widgets/currency_list_sheet.dart';

import '../../../../helpers/helpers.dart';

const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000,
);

void main() {
  group('CurrencyListSheet', () {
    late FakeCurrencyRepository repository;

    setUp(() => repository = FakeCurrencyRepository());
    tearDown(() => repository.close());

    /// Pumps a page with a button that opens the sheet, since a modal needs a
    /// Navigator to be pushed onto.
    Future<void> openSheet(WidgetTester tester) async {
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
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('says when there are no currencies', (tester) async {
      await openSheet(tester);

      expect(find.textContaining('No currencies yet'), findsOneWidget);
    });

    testWidgets('lists a currency with its rate', (tester) async {
      repository = FakeCurrencyRepository(initial: const [_euro]);
      await openSheet(tester);

      expect(find.text('EUR'), findsOneWidget);
      expect(find.text('1 EUR = 1.08 USD'), findsOneWidget);
    });

    testWidgets('adds a currency through the form', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byTooltip('Add currency'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(AppInput, 'Ticker'), 'gbp');
      await tester.enterText(
        find.widgetWithText(AppInput, 'Exchange rate'),
        '1.27',
      );
      await tester.pump();
      await tester.tap(find.text('Add currency').last);
      await tester.pumpAndSettle();

      final saved = (await repository.watchCurrencies().first).single;
      expect(saved.ticker, 'GBP');
      expect(saved.exchangeRateScaled, 1270000);
    });

    testWidgets('takes an emoji as the sign, from a tap', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byTooltip('Add currency'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '🪙'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(AppInput, 'Ticker'), 'gld');
      await tester.enterText(
        find.widgetWithText(AppInput, 'Exchange rate'),
        '1',
      );
      await tester.pump();
      await tester.tap(find.text('Add currency').last);
      await tester.pumpAndSettle();

      final saved = (await repository.watchCurrencies().first).single;
      expect(saved.icon, '🪙');
      expect(saved.label, '🪙', reason: 'shown instead of the ticker');
    });

    testWidgets('takes an emoji as the sign, typed', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byTooltip('Add currency'));
      await tester.pumpAndSettle();

      // Nothing filters the field, so an emoji keyboard works as well as a tap.
      await tester.enterText(find.widgetWithText(AppInput, 'Sign'), '🇪🇺');
      await tester.enterText(find.widgetWithText(AppInput, 'Ticker'), 'eur');
      await tester.enterText(
        find.widgetWithText(AppInput, 'Exchange rate'),
        '1.08',
      );
      await tester.pump();
      await tester.tap(find.text('Add currency').last);
      await tester.pumpAndSettle();

      expect((await repository.watchCurrencies().first).single.icon, '🇪🇺');
    });

    testWidgets('picking the chosen sign again clears it', (tester) async {
      await openSheet(tester);

      await tester.tap(find.byTooltip('Add currency'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, '€'));
      await tester.pump();
      await tester.tap(find.widgetWithText(ChoiceChip, '€'));
      await tester.pump();

      await tester.enterText(find.widgetWithText(AppInput, 'Ticker'), 'eur');
      await tester.enterText(
        find.widgetWithText(AppInput, 'Exchange rate'),
        '1.08',
      );
      await tester.pump();
      await tester.tap(find.text('Add currency').last);
      await tester.pumpAndSettle();

      final saved = (await repository.watchCurrencies().first).single;
      expect(saved.icon, isNull);
      expect(saved.label, 'EUR', reason: 'the ticker stands in for it');
    });

    testWidgets('removes a currency after confirming', (tester) async {
      repository = FakeCurrencyRepository(initial: const [_euro]);
      await openSheet(tester);

      await tester.tap(find.byTooltip('Remove EUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(await repository.watchCurrencies().first, isEmpty);
      expect(find.textContaining('No currencies yet'), findsOneWidget);
    });

    testWidgets('keeps the currency when the user cancels', (tester) async {
      repository = FakeCurrencyRepository(initial: const [_euro]);
      await openSheet(tester);

      await tester.tap(find.byTooltip('Remove EUR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await repository.watchCurrencies().first, hasLength(1));
    });
  });
}
