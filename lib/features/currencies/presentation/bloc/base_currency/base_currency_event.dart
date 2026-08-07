part of 'base_currency_bloc.dart';

sealed class BaseCurrencyEvent extends Equatable {
  const BaseCurrencyEvent();

  @override
  List<Object?> get props => [];
}

final class BaseCurrencySubscriptionRequested extends BaseCurrencyEvent {
  const BaseCurrencySubscriptionRequested();
}

/// Adopt [currency] as the base, removing the currencies quoted against the old
/// one.
///
/// Added only once the reader has agreed to the removals — the sheet asks, this
/// carries it out.
final class BaseCurrencyChosen extends BaseCurrencyEvent {
  const BaseCurrencyChosen(this.currency);

  final BaseCurrency currency;

  @override
  List<Object?> get props => [currency];
}
