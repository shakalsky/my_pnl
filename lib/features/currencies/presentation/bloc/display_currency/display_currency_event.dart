part of 'display_currency_bloc.dart';

sealed class DisplayCurrencyEvent extends Equatable {
  const DisplayCurrencyEvent();

  @override
  List<Object?> get props => [];
}

final class DisplayCurrencySubscriptionRequested extends DisplayCurrencyEvent {
  const DisplayCurrencySubscriptionRequested();
}

/// Move to the next currency, or back to the base once the list runs out.
final class DisplayCurrencyCycled extends DisplayCurrencyEvent {
  const DisplayCurrencyCycled();
}
