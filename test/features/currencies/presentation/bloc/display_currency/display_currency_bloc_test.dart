import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/read_display_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/save_display_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/display_currency/display_currency_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000,
);

const _pound = Currency(
  id: 'currency-2',
  ticker: 'GBP',
  exchangeRateScaled: 1270000,
);

void main() {
  group('DisplayCurrencyBloc', () {
    late FakeCurrencyRepository repository;
    late FakeDisplayCurrencyStore store;

    setUp(() {
      repository = FakeCurrencyRepository();
      store = FakeDisplayCurrencyStore();
    });
    tearDown(() => repository.close());

    DisplayCurrencyBloc build() => DisplayCurrencyBloc(
      watchCurrencies: WatchCurrencies(repository),
      readDisplayCurrency: ReadDisplayCurrency(store),
      saveDisplayCurrency: SaveDisplayCurrency(store),
    );

    /// Runs [act] and returns the state the bloc emits next.
    ///
    /// Subscribed before [act] runs: a write that finishes first would emit into
    /// a stream nobody is listening to yet, and the wait would never end.
    Future<DisplayCurrencyState> after(
      DisplayCurrencyBloc bloc,
      Future<void> Function() act,
    ) async {
      final next = bloc.stream.first;
      await act();
      return next;
    }

    blocTest<DisplayCurrencyBloc, DisplayCurrencyState>(
      'starts on the base currency with nothing to switch to',
      build: build,
      act: (bloc) => bloc.add(const DisplayCurrencySubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.selected, isNull);
        expect(bloc.state.label, r'$');
        expect(bloc.state.canCycle, isFalse);
        expect(bloc.state.convert(4235), 4235, reason: 'nothing to convert');
      },
    );

    blocTest<DisplayCurrencyBloc, DisplayCurrencyState>(
      'ignores a cycle when there is nowhere to go',
      build: build,
      act: (bloc) => bloc
        ..add(const DisplayCurrencySubscriptionRequested())
        ..add(const DisplayCurrencyCycled()),
      verify: (bloc) => expect(bloc.state.selected, isNull),
    );

    group('with two currencies', () {
      setUp(
        () => repository = FakeCurrencyRepository(
          initial: const [_euro, _pound],
        ),
      );

      test('cycles base to EUR to GBP and back', () async {
        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);
        expect(bloc.state.label, r'$');

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        expect(bloc.state.selected, _euro);
        expect(bloc.state.label, '€', reason: 'its sign, when it has one');

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        expect(bloc.state.selected, _pound);
        expect(bloc.state.label, 'GBP', reason: 'its ticker, when it has none');

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        expect(bloc.state.selected, isNull, reason: 'round to the base again');
        expect(bloc.state.label, r'$');
      });

      test('converts the total into whatever is selected', () async {
        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;

        // $42.35 at 1.08 to the euro.
        expect(bloc.state.convert(4235), 3921);
      });

      test('follows a rate that is edited while open', () async {
        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);
        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        expect(bloc.state.convert(4235), 3921);

        final updated = await after(
          bloc,
          () => repository.updateCurrency(
            const Currency(
              id: 'currency-1',
              ticker: 'EUR',
              icon: '€',
              exchangeRateScaled: 2000000, // 1 EUR = 2.00 USD
            ),
          ),
        );

        // The selection survives, at the new rate.
        expect(updated.selected?.id, _euro.id);
        expect(updated.convert(4235), 2118);
      });

      test('drops a selection that is deleted while open', () async {
        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);
        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        expect(bloc.state.selected, _euro);

        final without = await after(
          bloc,
          () => repository.deleteCurrency(_euro.id),
        );

        expect(without.selected, isNull, reason: 'back to the base');
        expect(without.label, r'$');
        expect(without.currencies, [_pound]);
      });
    });

    group('remembering the choice', () {
      setUp(
        () => repository = FakeCurrencyRepository(
          initial: const [_euro, _pound],
        ),
      );

      test('keeps every step of the cycle', () async {
        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;

        // Including the base, which is written as nothing rather than left as
        // the currency before it.
        expect(store.writes, [_euro.id, _pound.id, null]);
      });

      test('opens on the currency last chosen', () async {
        store = FakeDisplayCurrencyStore(remembered: _pound.id);

        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);

        expect(bloc.state.selected, _pound);
        expect(bloc.state.convert(4235), 3335);
      });

      test('carries on from there rather than starting over', () async {
        store = FakeDisplayCurrencyStore(remembered: _euro.id);

        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);
        expect(bloc.state.selected, _euro);

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;

        expect(bloc.state.selected, _pound, reason: 'the one after it');
      });

      test('opens on the base when the remembered currency is gone', () async {
        // Deleted on another device between runs.
        store = FakeDisplayCurrencyStore(remembered: 'currency-gone');

        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);

        expect(bloc.state.selected, isNull);
        expect(bloc.state.label, r'$');
      });

      test('a choice made now outranks the one remembered', () async {
        // The remembered currency has not synced down yet, so restoring it is
        // still pending when the reader taps.
        store = FakeDisplayCurrencyStore(remembered: 'currency-later');

        final bloc = build()
          ..add(const DisplayCurrencySubscriptionRequested());
        addTearDown(bloc.close);

        await bloc.stream.firstWhere((state) => state.canCycle);

        bloc.add(const DisplayCurrencyCycled());
        await bloc.stream.first;
        expect(bloc.state.selected, _euro);

        // The late arrival must not now yank the display away from the reader.
        final withNewcomer = await after(
          bloc,
          () => repository.createCurrency(
            const NewCurrency(ticker: 'ZAR', exchangeRateScaled: 55000),
          ),
        );

        expect(withNewcomer.selected, _euro);
      });
    });

    test('leaves out a currency whose rate cannot be divided by', () async {
      // Refused on save and by Postgres, so this is bad data rather than a
      // case to support — but it must not reach the arithmetic.
      repository = FakeCurrencyRepository(
        initial: const [
          Currency(id: 'bad', ticker: 'ZZZ', exchangeRateScaled: 0),
          _euro,
        ],
      );

      final bloc = build()..add(const DisplayCurrencySubscriptionRequested());
      addTearDown(bloc.close);

      await bloc.stream.firstWhere((state) => state.canCycle);

      expect(bloc.state.currencies, [_euro]);

      bloc.add(const DisplayCurrencyCycled());
      await bloc.stream.first;

      expect(bloc.state.selected, _euro);
      expect(bloc.state.convert(4235), 3921);
    });
  });
}
