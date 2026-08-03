part of 'currency_list_bloc.dart';

sealed class CurrencyListEvent extends Equatable {
  const CurrencyListEvent();

  @override
  List<Object?> get props => [];
}

final class CurrencyListSubscriptionRequested extends CurrencyListEvent {
  const CurrencyListSubscriptionRequested();
}

final class CurrencyDeleted extends CurrencyListEvent {
  const CurrencyDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
