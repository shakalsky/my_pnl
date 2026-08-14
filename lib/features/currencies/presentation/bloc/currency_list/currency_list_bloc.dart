import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/delete_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'currency_list_event.dart';
part 'currency_list_state.dart';

/// Drives the currencies modal.
class CurrencyListBloc extends Bloc<CurrencyListEvent, CurrencyListState> {
  CurrencyListBloc({
    required WatchCurrencies watchCurrencies,
    required DeleteCurrency deleteCurrency,
  }) : _watchCurrencies = watchCurrencies,
       _deleteCurrency = deleteCurrency,
       super(const CurrencyListState()) {
    on<CurrencyListSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<CurrencyDeleted>(_onDeleted);
  }

  final WatchCurrencies _watchCurrencies;
  final DeleteCurrency _deleteCurrency;

  Future<void> _onSubscriptionRequested(
    CurrencyListSubscriptionRequested event,
    Emitter<CurrencyListState> emit,
  ) async {
    emit(state.copyWith(status: CurrencyListStatus.loading));

    await emit.forEach<List<Currency>>(
      _watchCurrencies(),
      onData: (currencies) => state.copyWith(
        status: CurrencyListStatus.success,
        currencies: currencies,
        clearError: true,
      ),
      onError: (error, stackTrace) {
        log('Watching currencies failed', error: error, stackTrace: stackTrace);
        return state.copyWith(status: CurrencyListStatus.failure);
      },
    );
  }

  Future<void> _onDeleted(
    CurrencyDeleted event,
    Emitter<CurrencyListState> emit,
  ) async {
    try {
      await _deleteCurrency(event.id);
      // No emit on success: the watch stream carries the new list.
    } on Object {
      emit(state.copyWith(errorMessage: t.currencies.removeFailed));
    }
  }
}
