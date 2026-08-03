/// Fixed-point scales used for every numeric value in the app.
///
/// Nothing financial is stored as a floating point number: binary doubles
/// cannot represent 0.1, and the error compounds across a ledger. Values are
/// scaled integers so SQLite can still `SUM` and `GROUP BY` them.
library;

/// Amounts are stored scaled by this factor, i.e. with two decimal places.
///
/// This is the minor unit of most currencies — cents in USD/EUR. Always pair a
/// scaled amount with the currency code it was recorded in: zero-decimal
/// currencies such as JPY do not divide into hundredths, so the same integer
/// means a different thing depending on the currency.
const int amountScale = 100;

/// The currency every amount is understood to be in, and that exchange rates
/// are quoted against.
const String baseCurrency = 'USD';

/// What [baseCurrency] is written as in front of a figure.
const String baseCurrencySymbol = r'$';

/// Exchange rates are stored scaled by this factor, i.e. with six decimal
/// places.
///
/// Two would be far too coarse: a rate of 0.000023 is ordinary for a minor
/// currency against the base, and cents would round it to zero.
const int rateScale = 1000000;
