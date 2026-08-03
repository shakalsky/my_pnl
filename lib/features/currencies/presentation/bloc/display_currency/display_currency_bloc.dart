import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/conversion.dart';
import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/read_display_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/save_display_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';

part 'display_currency_event.dart';
part 'display_currency_state.dart';

/// Which currency totals are shown in.
///
/// Amounts stay in the base currency in the database; this only decides what the
/// reader sees. The choice itself is remembered, which is what makes the
/// spending page, the income page and the next run of the app agree on it —
/// each drives its own instance of this bloc, and the store is what they share.
class DisplayCurrencyBloc
    extends Bloc<DisplayCurrencyEvent, DisplayCurrencyState> {
  DisplayCurrencyBloc({
    required WatchCurrencies watchCurrencies,
    required ReadDisplayCurrency readDisplayCurrency,
    required SaveDisplayCurrency saveDisplayCurrency,
  }) : _watchCurrencies = watchCurrencies,
       _readDisplayCurrency = readDisplayCurrency,
       _saveDisplayCurrency = saveDisplayCurrency,
       super(const DisplayCurrencyState()) {
    on<DisplayCurrencySubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<DisplayCurrencyCycled>(_onCycled);
  }

  final WatchCurrencies _watchCurrencies;
  final ReadDisplayCurrency _readDisplayCurrency;
  final SaveDisplayCurrency _saveDisplayCurrency;

  /// The remembered choice, waiting for the currency it names to arrive.
  ///
  /// Held rather than applied at once because the id means nothing until the
  /// list is in: the currency it points at may have been deleted on another
  /// device, in which case nothing is restored. Cleared once it has been used,
  /// or as soon as the reader chooses for themselves.
  String? _remembered;

  Future<void> _onSubscriptionRequested(
    DisplayCurrencySubscriptionRequested event,
    Emitter<DisplayCurrencyState> emit,
  ) async {
    _remembered = await _readDisplayCurrency();

    await emit.forEach<List<Currency>>(
      _watchCurrencies(),
      onData: (currencies) {
        // A rate of zero or less cannot be divided by. Those rows are refused on
        // save and by Postgres, so one arriving here is bad data — leaving it
        // out of the cycle is better than a total nobody can explain.
        final usable = currencies
            .where((currency) => currency.exchangeRateScaled > 0)
            .toList(growable: false);

        // Re-read from the new list rather than kept: an edited rate has to
        // reach the figure on screen, and a deleted currency cannot stay
        // selected.
        var selected = _reselect(usable, state.selected);

        // Nothing chosen yet, so the remembered choice gets its turn. It only
        // gets one: after this the reader is in charge.
        if (selected == null && _remembered != null) {
          selected = _byId(usable, _remembered!);
          if (selected != null) _remembered = null;
        }

        return DisplayCurrencyState(currencies: usable, selected: selected);
      },
      onError: (error, stackTrace) {
        log('Watching currencies failed', error: error, stackTrace: stackTrace);
        // Nothing to switch to, so the total goes back to reading in the base.
        return const DisplayCurrencyState();
      },
    );
  }

  Future<void> _onCycled(
    DisplayCurrencyCycled event,
    Emitter<DisplayCurrencyState> emit,
  ) async {
    final next = state.next;

    // A choice of their own supersedes whatever was remembered, even if the
    // currency it named has not arrived yet.
    _remembered = null;

    emit(
      next == null
          ? state.copyWith(clearSelected: true)
          : state.copyWith(selected: next),
    );

    // Awaited so a failure is this handler's to swallow rather than an error
    // nobody is listening for. The store never throws, so this only waits.
    await _saveDisplayCurrency(next?.id);
  }

  /// The same currency out of [currencies], or null when it is no longer there.
  static Currency? _reselect(List<Currency> currencies, Currency? selected) =>
      selected == null ? null : _byId(currencies, selected.id);

  static Currency? _byId(List<Currency> currencies, String id) {
    for (final currency in currencies) {
      if (currency.id == id) return currency;
    }
    return null;
  }
}
