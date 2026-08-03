import 'package:equatable/equatable.dart';

/// A currency the user added.
class Currency extends Equatable {
  const Currency({
    required this.id,
    required this.ticker,
    required this.exchangeRateScaled,
    this.icon,
  });

  final String id;

  /// Short code, e.g. `EUR`. Stored upper-case.
  final String ticker;

  /// Optional symbol shown instead of the ticker, e.g. `€`.
  final String? icon;

  /// What one unit is worth in the base currency, scaled by `rateScale`.
  final int exchangeRateScaled;

  /// What to show in a tight space.
  String get label => icon ?? ticker;

  @override
  List<Object?> get props => [id, ticker, icon, exchangeRateScaled];
}

/// A currency that does not exist yet, so it has no id.
class NewCurrency extends Equatable {
  const NewCurrency({
    required this.ticker,
    required this.exchangeRateScaled,
    this.icon,
  });

  final String ticker;
  final String? icon;
  final int exchangeRateScaled;

  @override
  List<Object?> get props => [ticker, icon, exchangeRateScaled];
}
