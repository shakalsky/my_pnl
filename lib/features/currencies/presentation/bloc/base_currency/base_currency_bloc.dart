import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/core/money/currency_catalog.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/change_base_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/read_base_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'base_currency_event.dart';
part 'base_currency_state.dart';

/// Drives the sheet that changes which currency everything is recorded in.
///
/// Watches the added currencies as well as reading the base, because they are
/// what the change costs: the sheet has to say which of them will be removed
/// before the reader agrees to it, and the list has to be the one in force at
/// that moment rather than whatever it was when the sheet opened.
class BaseCurrencyBloc extends Bloc<BaseCurrencyEvent, BaseCurrencyState> {
  BaseCurrencyBloc({
    required ReadBaseCurrency readBaseCurrency,
    required WatchCurrencies watchCurrencies,
    required ChangeBaseCurrency changeBaseCurrency,
  }) : _readBaseCurrency = readBaseCurrency,
       _watchCurrencies = watchCurrencies,
       _changeBaseCurrency = changeBaseCurrency,
       super(const BaseCurrencyState()) {
    on<BaseCurrencySubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    // Sequential: the handler deletes rows and then writes a preference, and two
    // of those interleaving would leave the base and the rates disagreeing.
    on<BaseCurrencyChosen>(_onChosen, transformer: sequential());
  }

  final ReadBaseCurrency _readBaseCurrency;
  final WatchCurrencies _watchCurrencies;
  final ChangeBaseCurrency _changeBaseCurrency;

  Future<void> _onSubscriptionRequested(
    BaseCurrencySubscriptionRequested event,
    Emitter<BaseCurrencyState> emit,
  ) async {
    emit(state.copyWith(status: BaseCurrencyStatus.loading));

    // Read rather than watched: the only thing that changes it is this sheet,
    // which closes as soon as it has.
    emit(state.copyWith(base: await _readBaseCurrency()));

    await emit.forEach<List<Currency>>(
      _watchCurrencies(),
      onData: (currencies) => state.copyWith(
        status: BaseCurrencyStatus.success,
        currencies: currencies,
      ),
      onError: (error, stackTrace) {
        log('Watching currencies failed', error: error, stackTrace: stackTrace);
        // Failed rather than shown as an empty list: a change made against a
        // list nobody could load would remove currencies the reader was never
        // warned about.
        return state.copyWith(status: BaseCurrencyStatus.failure);
      },
    );
  }

  Future<void> _onChosen(
    BaseCurrencyChosen event,
    Emitter<BaseCurrencyState> emit,
  ) async {
    // Nothing is changed against a list that has not arrived: the removals are
    // taken from it, so acting early would adopt the new base and leave the old
    // rates behind, still saying they are quoted against a currency that is no
    // longer the base. The sheet only offers the choice once the list is in;
    // this is what makes that a rule rather than a matter of timing.
    if (state.status != BaseCurrencyStatus.success) return;

    // Choosing what is already in force is not a change, and going through with
    // it would delete the added currencies for nothing.
    if (event.currency == state.base) return;

    emit(state.copyWith(isSubmitting: true, clearError: true));

    try {
      await _changeBaseCurrency(
        currency: event.currency,
        existing: state.currencies,
      );

      emit(
        state.copyWith(
          isSubmitting: false,
          base: event.currency,
          changed: true,
        ),
      );
    } on CurrencyFailure catch (failure) {
      emit(state.copyWith(isSubmitting: false, errorMessage: failure.message));
    } on Object catch (error, stackTrace) {
      log(
        'Changing the base currency failed',
        error: error,
        stackTrace: stackTrace,
      );
      // Some of the removals may have gone through, which the list on screen
      // shows. The base is untouched, so the rates that are left still mean what
      // they say.
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: t.currencies.baseChangeFailed,
        ),
      );
    }
  }
}
