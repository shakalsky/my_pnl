part of 'currency_form_bloc.dart';

enum CurrencyFormStatus { editing, submitting, success, failure }

final class CurrencyFormState extends Equatable {
  const CurrencyFormState({
    this.currencyId,
    this.ticker = '',
    this.icon = '',
    this.rate = '',
    this.status = CurrencyFormStatus.editing,
    this.errorMessage,
  });

  /// Null while adding; set to the currency being changed.
  final String? currencyId;

  final String ticker;
  final String icon;

  /// What the user typed for the rate. Kept as text so the field never fights
  /// the cursor.
  final String rate;

  final CurrencyFormStatus status;
  final String? errorMessage;

  bool get isEditing => currencyId != null;

  /// The parsed rate, or null while the input is not a number.
  int? get exchangeRateScaled => parseRate(rate);

  bool get isSubmitting => status == CurrencyFormStatus.submitting;

  /// Enough to enable the button. The use case validates properly, and
  /// Postgres has the final say on uniqueness.
  bool get isValid => switch (exchangeRateScaled) {
    null || <= 0 => false,
    _ => ticker.trim().isNotEmpty,
  };

  CurrencyFormState copyWith({
    String? ticker,
    String? icon,
    String? rate,
    CurrencyFormStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CurrencyFormState(
      currencyId: currencyId,
      ticker: ticker ?? this.ticker,
      icon: icon ?? this.icon,
      rate: rate ?? this.rate,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    currencyId,
    ticker,
    icon,
    rate,
    status,
    errorMessage,
  ];
}
