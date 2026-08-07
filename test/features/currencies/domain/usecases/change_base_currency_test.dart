import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/change_base_currency.dart';

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

const _euroBase = BaseCurrency(ticker: 'EUR', symbol: '€');

void main() {
  group('ChangeBaseCurrency', () {
    late FakeCurrencyRepository repository;
    late FakeBaseCurrencyStore store;

    ChangeBaseCurrency build({List<Currency> initial = const []}) {
      repository = FakeCurrencyRepository(initial: initial);
      store = FakeBaseCurrencyStore();
      return ChangeBaseCurrency(repository: repository, store: store);
    }

    tearDown(() async {
      await repository.close();
      await store.close();
    });

    test('remembers the new base', () async {
      final changeBaseCurrency = build();

      await changeBaseCurrency(currency: _euroBase, existing: const []);

      expect(store.writes, [_euroBase]);
      expect(await store.read(), _euroBase);
    });

    test('deletes the currencies quoted against the old base', () async {
      final changeBaseCurrency = build(initial: const [_euro, _zloty]);

      await changeBaseCurrency(
        currency: const BaseCurrency(ticker: 'GBP', symbol: '£'),
        existing: const [_euro, _zloty],
      );

      expect(await repository.watchCurrencies().first, isEmpty);
    });

    test('deletes the chosen currency along with the rest', () async {
      final changeBaseCurrency = build(initial: const [_euro, _zloty]);

      // EUR was one of the added currencies. It is the base now, so there is no
      // rate left for it to hold and no place for it in the list.
      await changeBaseCurrency(
        currency: _euroBase,
        existing: const [_euro, _zloty],
      );

      expect(await repository.watchCurrencies().first, isEmpty);
      expect(await store.read(), _euroBase);
    });

    test('leaves the base alone when a removal fails', () async {
      final changeBaseCurrency = build(initial: const [_euro]);
      repository.writeError = Exception('nope');

      await expectLater(
        changeBaseCurrency(currency: _euroBase, existing: const [_euro]),
        throwsException,
      );

      expect(
        store.writes,
        isEmpty,
        reason: 'the rates left behind still mean what they say',
      );
      expect(await repository.watchCurrencies().first, [_euro]);
    });

    test('refuses a currency the app cannot label a figure with', () async {
      final changeBaseCurrency = build(initial: const [_euro]);

      await expectLater(
        changeBaseCurrency(
          currency: const BaseCurrency(ticker: 'eur', symbol: '€'),
          existing: const [_euro],
        ),
        throwsA(isA<CurrencyFailure>()),
      );

      expect(store.writes, isEmpty);
      expect(
        await repository.watchCurrencies().first,
        [_euro],
        reason: 'nothing is removed for a change that cannot happen',
      );
    });
  });
}
