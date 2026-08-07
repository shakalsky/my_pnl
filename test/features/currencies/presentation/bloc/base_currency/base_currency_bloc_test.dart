import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/change_base_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/read_base_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/base_currency/base_currency_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000,
);

const _pound = BaseCurrency(ticker: 'GBP', symbol: '£');

/// Subscribes, waits for the list, and only then chooses — which is the order
/// the sheet does it in, since the choice is not offered until the list is in.
Future<void> _chooseOnceLoaded(BaseCurrencyBloc bloc, BaseCurrency base) async {
  bloc.add(const BaseCurrencySubscriptionRequested());
  await bloc.stream.firstWhere(
    (state) => state.status == BaseCurrencyStatus.success,
  );
  bloc.add(BaseCurrencyChosen(base));
}

void main() {
  group('BaseCurrencyBloc', () {
    late FakeCurrencyRepository repository;
    late FakeBaseCurrencyStore store;

    BaseCurrencyBloc build({
      List<Currency> currencies = const [],
      BaseCurrency base = BaseCurrency.usd,
    }) {
      repository = FakeCurrencyRepository(initial: currencies);
      store = FakeBaseCurrencyStore(initial: base);

      return BaseCurrencyBloc(
        readBaseCurrency: ReadBaseCurrency(store),
        watchCurrencies: WatchCurrencies(repository),
        changeBaseCurrency: ChangeBaseCurrency(
          repository: repository,
          store: store,
        ),
      );
    }

    tearDown(() async {
      await repository.close();
      await store.close();
    });

    blocTest<BaseCurrencyBloc, BaseCurrencyState>(
      'opens on the base in force and what is quoted against it',
      build: () => build(
        currencies: const [_euro],
        base: const BaseCurrency(ticker: 'PLN', symbol: 'zł'),
      ),
      act: (bloc) => bloc.add(const BaseCurrencySubscriptionRequested()),
      expect: () => const <BaseCurrencyState>[
        BaseCurrencyState(status: BaseCurrencyStatus.loading),
        // The stored base lands before the list does: it is read, not watched.
        BaseCurrencyState(
          status: BaseCurrencyStatus.loading,
          base: BaseCurrency(ticker: 'PLN', symbol: 'zł'),
        ),
        BaseCurrencyState(
          status: BaseCurrencyStatus.success,
          base: BaseCurrency(ticker: 'PLN', symbol: 'zł'),
          currencies: [_euro],
        ),
      ],
    );

    blocTest<BaseCurrencyBloc, BaseCurrencyState>(
      'reports a list it could not load rather than an empty one',
      build: () {
        final bloc = build(currencies: const [_euro]);
        repository.watchError = Exception('nope');
        return bloc;
      },
      act: (bloc) => bloc.add(const BaseCurrencySubscriptionRequested()),
      // Offering the choice against a list nobody could load would remove
      // currencies the reader was never warned about.
      verify: (bloc) =>
          expect(bloc.state.status, BaseCurrencyStatus.failure),
    );

    blocTest<BaseCurrencyBloc, BaseCurrencyState>(
      'adopts the chosen currency and clears the old rates',
      build: () => build(currencies: const [_euro]),
      act: (bloc) => _chooseOnceLoaded(bloc, _pound),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) async {
        expect(bloc.state.base, _pound);
        expect(bloc.state.changed, isTrue);
        expect(bloc.state.currencies, isEmpty);
        expect(store.writes, [_pound]);
        expect(await repository.watchCurrencies().first, isEmpty);
      },
    );

    blocTest<BaseCurrencyBloc, BaseCurrencyState>(
      'does nothing when the base chosen is the one in force',
      build: () => build(currencies: const [_euro]),
      act: (bloc) => _chooseOnceLoaded(bloc, BaseCurrency.usd),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) async {
        expect(bloc.state.changed, isFalse);
        expect(store.writes, isEmpty);
        expect(
          await repository.watchCurrencies().first,
          [_euro],
          reason: 'a change that is not one does not delete anything',
        );
      },
    );

    blocTest<BaseCurrencyBloc, BaseCurrencyState>(
      'says so when the change fails, and stays on the old base',
      build: () {
        final bloc = build(currencies: const [_euro]);
        repository.writeError = Exception('nope');
        return bloc;
      },
      act: (bloc) => _chooseOnceLoaded(bloc, _pound),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.errorMessage, 'Could not change the base currency');
        expect(bloc.state.changed, isFalse);
        expect(bloc.state.base, BaseCurrency.usd);
        expect(bloc.state.isSubmitting, isFalse);
        expect(store.writes, isEmpty);
      },
    );

    blocTest<BaseCurrencyBloc, BaseCurrencyState>(
      'refuses a change made before the list has arrived',
      build: () => build(currencies: const [_euro]),
      // Straight in, without waiting: the removals come from the list, so acting
      // now would adopt the new base and leave the old rates behind it.
      act: (bloc) => bloc
        ..add(const BaseCurrencySubscriptionRequested())
        ..add(const BaseCurrencyChosen(_pound)),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) async {
        expect(bloc.state.base, BaseCurrency.usd);
        expect(bloc.state.changed, isFalse);
        expect(store.writes, isEmpty);
        expect(await repository.watchCurrencies().first, [_euro]);
      },
    );

    group('the currencies on offer', () {
      test('fall back to the catalogue when nothing was added', () {
        const state = BaseCurrencyState();

        expect(state.options.first.ticker, 'USD');
        expect(
          state.options.map((option) => option.ticker),
          containsAll(['EUR', 'GBP', 'PLN']),
        );
      });

      test('lead with the ones the reader added, signs and all', () {
        const state = BaseCurrencyState(
          currencies: [
            Currency(id: 'c-1', ticker: 'GLD', icon: '🪙', exchangeRateScaled: 1),
          ],
        );

        final added = state.options.first;
        expect(added.ticker, 'GLD');
        expect(added.symbol, '🪙');
        expect(added.name, 'One you added');
      });

      test('name an added currency once, not twice', () {
        const state = BaseCurrencyState(currencies: [_euro]);

        expect(
          state.options.where((option) => option.ticker == 'EUR'),
          hasLength(1),
        );
      });

      test("put a base of the reader's own making first", () {
        const state = BaseCurrencyState(
          base: BaseCurrency(ticker: 'GLD', symbol: '🪙'),
        );

        expect(state.options.first.ticker, 'GLD');
      });
    });
  });
}
