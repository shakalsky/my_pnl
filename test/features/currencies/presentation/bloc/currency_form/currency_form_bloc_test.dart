import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/save_currency.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/currency_form/currency_form_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _euro = Currency(
  id: 'currency-1',
  ticker: 'EUR',
  icon: '€',
  exchangeRateScaled: 1080000,
);

void main() {
  group('CurrencyFormBloc', () {
    late FakeCurrencyRepository repository;

    setUp(() => repository = FakeCurrencyRepository());
    tearDown(() => repository.close());

    CurrencyFormBloc build({Currency? initial}) => CurrencyFormBloc(
      saveCurrency: SaveCurrency(repository),
      initial: initial,
    );

    group('adding', () {
      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'needs both a ticker and a rate above zero',
        build: build,
        act: (bloc) => bloc.add(const CurrencyTickerChanged('EUR')),
        verify: (bloc) => expect(bloc.state.isValid, isFalse),
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'rejects a zero rate',
        build: build,
        act: (bloc) => bloc
          ..add(const CurrencyTickerChanged('EUR'))
          ..add(const CurrencyRateChanged('0')),
        verify: (bloc) => expect(bloc.state.isValid, isFalse),
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'parses the rate to six decimal places',
        build: build,
        act: (bloc) => bloc
          ..add(const CurrencyTickerChanged('BTC'))
          ..add(const CurrencyRateChanged('0.000023')),
        verify: (bloc) => expect(bloc.state.exchangeRateScaled, 23),
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'saves the currency',
        build: build,
        act: (bloc) => bloc
          ..add(const CurrencyTickerChanged('eur'))
          ..add(const CurrencyIconChanged('€'))
          ..add(const CurrencyRateChanged('1.08'))
          ..add(const CurrencyFormSubmitted()),
        verify: (bloc) async {
          expect(bloc.state.status, CurrencyFormStatus.success);

          final saved = (await repository.watchCurrencies().first).single;
          expect(saved.ticker, 'EUR', reason: 'upper-cased on save');
          expect(saved.icon, '€');
          expect(saved.exchangeRateScaled, 1080000);
        },
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'stores a blank icon as none',
        build: build,
        act: (bloc) => bloc
          ..add(const CurrencyTickerChanged('EUR'))
          ..add(const CurrencyIconChanged('  '))
          ..add(const CurrencyRateChanged('1.08'))
          ..add(const CurrencyFormSubmitted()),
        verify: (bloc) async {
          final saved = (await repository.watchCurrencies().first).single;
          expect(saved.icon, isNull);
        },
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'refuses the base currency',
        build: build,
        act: (bloc) => bloc
          ..add(const CurrencyTickerChanged('USD'))
          ..add(const CurrencyRateChanged('1'))
          ..add(const CurrencyFormSubmitted()),
        verify: (bloc) {
          expect(bloc.state.errorMessage, 'USD is the base currency');
          expect(bloc.state.status, CurrencyFormStatus.editing);
        },
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'names the clash when the ticker is taken',
        build: () {
          repository = FakeCurrencyRepository(initial: const [_euro]);
          return build();
        },
        act: (bloc) => bloc
          ..add(const CurrencyTickerChanged('EUR'))
          ..add(const CurrencyRateChanged('1.09'))
          ..add(const CurrencyFormSubmitted()),
        verify: (bloc) {
          expect(bloc.state.errorMessage, 'EUR is already in your list');
          expect(bloc.state.ticker, 'EUR', reason: 'input survives');
        },
      );
    });

    group('editing', () {
      setUp(() => repository = FakeCurrencyRepository(initial: const [_euro]));

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'opens with the current values, rate trimmed',
        build: () => build(initial: _euro),
        verify: (bloc) {
          expect(bloc.state.isEditing, isTrue);
          expect(bloc.state.ticker, 'EUR');
          expect(bloc.state.icon, '€');
          expect(bloc.state.rate, '1.08');
        },
      );

      blocTest<CurrencyFormBloc, CurrencyFormState>(
        'changes the existing currency rather than adding one',
        build: () => build(initial: _euro),
        act: (bloc) => bloc
          ..add(const CurrencyRateChanged('1.09'))
          ..add(const CurrencyFormSubmitted()),
        verify: (bloc) async {
          final currencies = await repository.watchCurrencies().first;
          expect(currencies, hasLength(1));
          expect(currencies.single.id, _euro.id);
          expect(currencies.single.exchangeRateScaled, 1090000);
        },
      );
    });
  });
}
