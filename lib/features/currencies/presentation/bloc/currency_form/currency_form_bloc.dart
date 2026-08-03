import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/amount_parse.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/usecases/save_currency.dart';

part 'currency_form_event.dart';
part 'currency_form_state.dart';

/// Drives the add/edit currency modal.
///
/// One modal, one bloc: adding and editing differ only in whether the form
/// starts with a currency behind it.
class CurrencyFormBloc extends Bloc<CurrencyFormEvent, CurrencyFormState> {
  CurrencyFormBloc({required SaveCurrency saveCurrency, Currency? initial})
    : _saveCurrency = saveCurrency,
      super(
        CurrencyFormState(
          currencyId: initial?.id,
          ticker: initial?.ticker ?? '',
          icon: initial?.icon ?? '',
          rate: initial == null ? '' : formatRate(initial.exchangeRateScaled),
        ),
      ) {
    on<CurrencyTickerChanged>(
      (event, emit) =>
          emit(state.copyWith(ticker: event.ticker, clearError: true)),
    );
    on<CurrencyIconChanged>(
      (event, emit) => emit(state.copyWith(icon: event.icon)),
    );
    on<CurrencyRateChanged>(
      (event, emit) => emit(state.copyWith(rate: event.rate, clearError: true)),
    );
    on<CurrencyFormSubmitted>(_onSubmitted);
  }

  final SaveCurrency _saveCurrency;

  Future<void> _onSubmitted(
    CurrencyFormSubmitted event,
    Emitter<CurrencyFormState> emit,
  ) async {
    final rate = state.exchangeRateScaled;
    if (!state.isValid || rate == null || state.isSubmitting) return;

    emit(
      state.copyWith(status: CurrencyFormStatus.submitting, clearError: true),
    );

    try {
      if (state.currencyId case final id?) {
        await _saveCurrency.update(
          Currency(
            id: id,
            ticker: state.ticker,
            icon: state.icon,
            exchangeRateScaled: rate,
          ),
        );
      } else {
        await _saveCurrency.create(
          NewCurrency(
            ticker: state.ticker,
            icon: state.icon,
            exchangeRateScaled: rate,
          ),
        );
      }
      emit(state.copyWith(status: CurrencyFormStatus.success));
    } on CurrencyFailure catch (e) {
      // A rejected ticker or duplicate: worth naming, and the form stays
      // filled in so it can be corrected.
      emit(
        state.copyWith(
          status: CurrencyFormStatus.failure,
          errorMessage: e.message,
        ),
      );
      emit(state.copyWith(status: CurrencyFormStatus.editing));
    } on Object {
      emit(
        state.copyWith(
          status: CurrencyFormStatus.failure,
          errorMessage: 'Could not save that currency',
        ),
      );
      emit(state.copyWith(status: CurrencyFormStatus.editing));
    }
  }
}
