part of 'currency_list_bloc.dart';

enum CurrencyListStatus { initial, loading, success, failure }

final class CurrencyListState extends Equatable {
  const CurrencyListState({
    this.status = CurrencyListStatus.initial,
    this.currencies = const [],
    this.errorMessage,
  });

  final CurrencyListStatus status;
  final List<Currency> currencies;

  /// A failed delete. Separate from [status] so a transient error shows over
  /// the list rather than replacing it.
  final String? errorMessage;

  CurrencyListState copyWith({
    CurrencyListStatus? status,
    List<Currency>? currencies,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CurrencyListState(
      status: status ?? this.status,
      currencies: currencies ?? this.currencies,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, currencies, errorMessage];
}
