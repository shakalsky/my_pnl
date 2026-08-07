import 'package:equatable/equatable.dart';

/// The currency amounts are recorded in, and that exchange rates are quoted
/// against.
///
/// A pair rather than a ticker on its own: the ticker is what a rate is labelled
/// with (`1 EUR = 1.08 USD`) and the symbol is what leads a figure (`$42.35`),
/// and the two are not interchangeable in either place.
class BaseCurrency extends Equatable {
  const BaseCurrency({required this.ticker, required this.symbol});

  /// What the app ships with, and what it falls back to when the stored choice
  /// cannot be read or makes no sense.
  static const usd = BaseCurrency(ticker: 'USD', symbol: r'$');

  /// Short code, upper-case, e.g. `USD`.
  final String ticker;

  /// What is written in front of a figure — `$`, `€`, or the ticker itself for a
  /// currency with no sign of its own.
  final String symbol;

  /// Whether this is a currency the rest of the app can work with.
  ///
  /// The same shape `SaveCurrency` demands of a ticker, so the base and the
  /// currencies quoted against it cannot disagree about what a ticker is.
  bool get isValid =>
      RegExp(r'^[A-Z0-9]{2,10}$').hasMatch(ticker) && symbol.isNotEmpty;

  @override
  List<Object?> get props => [ticker, symbol];
}

/// The base currency in force for this run.
///
/// A single mutable value rather than something threaded through the widget
/// tree: every figure in the app goes through `formatAmount`, a top-level
/// function, and the base is the one thing it needs that the caller does not
/// have. Setting it is the app shell's business — it does so once at startup and
/// again whenever the stored choice changes, and rebuilds beneath itself so what
/// is on screen agrees with it.
BaseCurrency get activeBaseCurrency => _active;

/// Replaces what [activeBaseCurrency] reports.
///
/// Refuses a currency the app cannot work with rather than leaving figures
/// labelled with nothing: an empty or malformed ticker only reaches here from a
/// preference an older or newer build wrote.
void setActiveBaseCurrency(BaseCurrency currency) {
  if (currency.isValid) _active = currency;
}

BaseCurrency _active = BaseCurrency.usd;
