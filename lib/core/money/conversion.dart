import 'package:my_pnl/core/money/scales.dart';

/// A base-currency amount expressed in another currency.
///
/// [exchangeRateScaled] is what one unit of the other currency is worth in the
/// base — the figure the currencies sheet stores and labels "what 1 EUR is worth
/// in USD" — so this divides by it rather than multiplying. A $42.35 total at
/// 1.08 to the euro is €39.21, and the same total against a currency worth
/// 0.000023 of a dollar is a great many of them.
///
/// Integer arithmetic throughout, like every other amount in the app: the
/// intermediate is `amountScaled × rateScale`, which stays inside a 64-bit
/// integer for any total up to roughly nine billion dollars.
///
/// The result keeps the app's two decimal places, which is the whole precision
/// there is to work with. A currency worth far more than the base — a coin at
/// tens of thousands to the dollar — therefore rounds a small total to zero.
///
/// Throws [ArgumentError] on a rate of zero or less. `SaveCurrency` rejects
/// those and Postgres has a check constraint against them, so a caller holding
/// one has bad data rather than an unusual case: better to hear about it than to
/// show a figure that is quietly wrong.
int convertFromBase({
  required int amountScaled,
  required int exchangeRateScaled,
}) {
  if (exchangeRateScaled <= 0) {
    throw ArgumentError.value(
      exchangeRateScaled,
      'exchangeRateScaled',
      'must be above zero',
    );
  }

  final magnitude = amountScaled.abs();
  // Rounded rather than truncated, and worked out on the magnitude so the
  // rounding stays symmetric either side of zero.
  final converted =
      (magnitude * rateScale + exchangeRateScaled ~/ 2) ~/ exchangeRateScaled;

  return amountScaled.isNegative ? -converted : converted;
}
