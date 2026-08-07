part of 'base_currency_bloc.dart';

enum BaseCurrencyStatus { initial, loading, success, failure }

final class BaseCurrencyState extends Equatable {
  const BaseCurrencyState({
    this.status = BaseCurrencyStatus.initial,
    this.base = BaseCurrency.usd,
    this.currencies = const [],
    this.isSubmitting = false,
    this.changed = false,
    this.errorMessage,
  });

  final BaseCurrencyStatus status;

  /// What everything is recorded in now.
  final BaseCurrency base;

  /// The currencies quoted against [base] — what a change would remove.
  final List<Currency> currencies;

  final bool isSubmitting;

  /// Whether the base has been changed, which is what closes the sheet.
  final bool changed;

  /// A failed change. Separate from [status] so it shows over the list rather
  /// than replacing it.
  final String? errorMessage;

  /// What can be chosen: the base itself, the currencies the reader added, and
  /// then the ones the app knows of.
  ///
  /// Their own currencies come first, and ahead of the catalogue: someone whose
  /// money is in one of them has already said so once, so it is the likelier
  /// choice — and a currency the catalogue has never heard of would otherwise sit
  /// below thirty they did not pick.
  List<CatalogCurrency> get options {
    final tickers = <String>{};
    final options = <CatalogCurrency>[];

    void offer(CatalogCurrency option) {
      if (tickers.add(option.ticker)) options.add(option);
    }

    // The base of the moment, when it is one the catalogue does not carry — the
    // reader's own, adopted earlier.
    if (!currencyCatalog.any((entry) => entry.ticker == base.ticker)) {
      offer(
        CatalogCurrency(
          ticker: base.ticker,
          symbol: base.symbol,
          name: 'Your base currency',
        ),
      );
    }

    for (final currency in currencies) {
      offer(
        CatalogCurrency(
          ticker: currency.ticker,
          // The sign it is already shown with, or its ticker when it has none.
          symbol: currency.label,
          name: 'One you added',
        ),
      );
    }

    currencyCatalog.forEach(offer);

    return List.unmodifiable(options);
  }

  BaseCurrencyState copyWith({
    BaseCurrencyStatus? status,
    BaseCurrency? base,
    List<Currency>? currencies,
    bool? isSubmitting,
    bool? changed,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BaseCurrencyState(
      status: status ?? this.status,
      base: base ?? this.base,
      currencies: currencies ?? this.currencies,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      changed: changed ?? this.changed,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    base,
    currencies,
    isSubmitting,
    changed,
    errorMessage,
  ];
}
