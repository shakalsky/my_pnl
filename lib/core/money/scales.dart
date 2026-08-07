/// Fixed-point scales used for every numeric value in the app.
///
/// Nothing financial is stored as a floating point number: binary doubles
/// cannot represent 0.1, and the error compounds across a ledger. Values are
/// scaled integers so SQLite can still `SUM` and `GROUP BY` them.
library;

import 'package:my_pnl/core/money/base_currency.dart';

/// Amounts are stored scaled by this factor, i.e. with two decimal places.
///
/// This is the minor unit of most currencies — cents in USD/EUR. Always pair a
/// scaled amount with the currency code it was recorded in: zero-decimal
/// currencies such as JPY do not divide into hundredths, so the same integer
/// means a different thing depending on the currency.
const int amountScale = 100;

/// The currency every amount is understood to be in, and that exchange rates
/// are quoted against.
///
/// Not a constant any more: the reader chooses it in the currencies sheet, and
/// `BaseCurrencyStore` is what remembers the choice. Reads the value the app
/// shell has set for this run — `BaseCurrency.usd` until something sets another.
String get baseCurrency => activeBaseCurrency.ticker;

/// What [baseCurrency] is written as in front of a figure.
String get baseCurrencySymbol => activeBaseCurrency.symbol;

/// Exchange rates are stored scaled by this factor, i.e. with six decimal
/// places.
///
/// Two would be far too coarse: a rate of 0.000023 is ordinary for a minor
/// currency against the base, and cents would round it to zero.
const int rateScale = 1000000;
