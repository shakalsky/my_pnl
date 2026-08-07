import 'dart:async';
import 'dart:developer';

import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Keeps the base currency in the platform's own key-value store.
class PreferencesBaseCurrencyStore implements BaseCurrencyStore {
  PreferencesBaseCurrencyStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  /// Prefixed, because these preferences share a namespace with every other
  /// plugin's.
  static const tickerKey = 'my_pnl.base_currency_ticker';
  static const symbolKey = 'my_pnl.base_currency_symbol';

  final SharedPreferencesAsync _preferences;

  /// Broadcasts a save to whatever is already on screen.
  ///
  /// The platform store has no change notification of its own, so the one write
  /// path is what tells the readers. Broadcast because the app shell and the
  /// sheet that changes the setting both listen.
  final _changes = StreamController<BaseCurrency>.broadcast();

  @override
  Stream<BaseCurrency> watch() async* {
    yield await read();
    yield* _changes.stream;
  }

  @override
  Future<BaseCurrency> read() async {
    try {
      final ticker = await _preferences.getString(tickerKey);
      if (ticker == null) return BaseCurrency.usd;

      final stored = BaseCurrency(
        ticker: ticker,
        // A currency with no sign of its own is labelled with its ticker, which
        // is also what a build that wrote the ticker but not the symbol leaves
        // behind.
        symbol: await _preferences.getString(symbolKey) ?? ticker,
      );

      // Checked on the way out rather than trusted: this came from a store an
      // older or newer build may have written, and a malformed ticker would
      // label every figure in the app with nonsense.
      return stored.isValid ? stored : BaseCurrency.usd;
    } on Object catch (e, s) {
      // A store that will not open is the same as an untouched one: amounts read
      // in the currency the app ships with.
      log('Reading the base currency failed', error: e, stackTrace: s);
      return BaseCurrency.usd;
    }
  }

  @override
  Future<void> write(BaseCurrency currency) async {
    try {
      await _preferences.setString(tickerKey, currency.ticker);
      await _preferences.setString(symbolKey, currency.symbol);
    } on Object catch (e, s) {
      // Swallowed: the choice still applies for this run, it just will not
      // survive a restart, and that is not worth a message over.
      log('Remembering the base currency failed', error: e, stackTrace: s);
    }

    // Announced either way. What is on screen has to agree with what the user
    // just chose even when the store refused to keep it.
    if (!_changes.isClosed) _changes.add(currency);
  }

  /// Stops broadcasting. For tests; the app holds one of these for its life.
  Future<void> close() => _changes.close();
}
