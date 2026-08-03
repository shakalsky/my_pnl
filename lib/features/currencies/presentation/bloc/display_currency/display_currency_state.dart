part of 'display_currency_bloc.dart';

final class DisplayCurrencyState extends Equatable {
  const DisplayCurrencyState({this.currencies = const [], this.selected});

  /// What can be switched to, in the order the cycle visits them. The base is
  /// not among them: it is the state of having nothing selected.
  final List<Currency> currencies;

  /// Null while totals read in the base currency.
  final Currency? selected;

  /// Whether there is anything to switch to at all.
  bool get canCycle => currencies.isNotEmpty;

  /// What to put beside a figure — the selected currency's symbol or ticker, or
  /// the base currency's sign.
  String get label => selected?.label ?? baseCurrencySymbol;

  /// [amountScaled] read in the selected currency, or unchanged on the base.
  int convert(int amountScaled) => switch (selected) {
    null => amountScaled,
    final currency => convertFromBase(
      amountScaled: amountScaled,
      exchangeRateScaled: currency.exchangeRateScaled,
    ),
  };

  /// Where the next tap lands: the currency after [selected], or null for the
  /// base once the list has been walked through.
  ///
  /// A selection that has since been deleted counts as being before the start,
  /// so the cycle picks up from the first currency rather than stalling.
  Currency? get next {
    if (currencies.isEmpty) return null;

    final at = selected == null
        ? -1
        : currencies.indexWhere((currency) => currency.id == selected!.id);

    final nextIndex = at + 1;
    return nextIndex >= currencies.length ? null : currencies[nextIndex];
  }

  DisplayCurrencyState copyWith({
    List<Currency>? currencies,
    Currency? selected,
    bool clearSelected = false,
  }) {
    return DisplayCurrencyState(
      currencies: currencies ?? this.currencies,
      selected: clearSelected ? null : selected ?? this.selected,
    );
  }

  @override
  List<Object?> get props => [currencies, selected];
}
