part of 'currency_form_bloc.dart';

sealed class CurrencyFormEvent extends Equatable {
  const CurrencyFormEvent();

  @override
  List<Object?> get props => [];
}

final class CurrencyTickerChanged extends CurrencyFormEvent {
  const CurrencyTickerChanged(this.ticker);

  final String ticker;

  @override
  List<Object?> get props => [ticker];
}

final class CurrencyIconChanged extends CurrencyFormEvent {
  const CurrencyIconChanged(this.icon);

  final String icon;

  @override
  List<Object?> get props => [icon];
}

final class CurrencyRateChanged extends CurrencyFormEvent {
  const CurrencyRateChanged(this.rate);

  /// Raw text, exactly as typed.
  final String rate;

  @override
  List<Object?> get props => [rate];
}

final class CurrencyFormSubmitted extends CurrencyFormEvent {
  const CurrencyFormSubmitted();
}
