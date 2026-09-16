import 'package:my_pnl/core/money/scales.dart';

/// Formats a scaled amount for display without ever going through a double.
String formatAmount(int scaled) => formatAmountIn(scaled, baseCurrencySymbol);

/// A label of nothing but letters and digits: `EUR`, `SEK`, `USD`.
///
/// Which is exactly what `SaveCurrency` allows a ticker to be, so anything else
/// — `$`, `€`, `₿`, an emoji — is a sign.
final _tickerPattern = RegExp(r'^[A-Za-z0-9]+$');

/// [formatAmount] with another currency's label.
///
/// A ticker follows the digits (`39.21 SEK`), because `SEK39.21` reads as one
/// word rather than as an amount. A sign leads them (`-€39.21`), whether it is
/// one code unit like `€` or several like an emoji — matched by what the label
/// is not, so a flag or a multi-part emoji lands in front like any other sign.
String formatAmountIn(int scaled, String label) {
  final isNegative = scaled < 0;
  final absolute = scaled.abs();
  final major = (absolute ~/ amountScale).toString();
  final minor = (absolute % amountScale).toString().padLeft(2, '0');
  final grouped = major.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (match) => '${match[1]},',
  );

  final sign = isNegative ? '-' : '';
  final digits = '$grouped.$minor';

  // No space after the sign: it belongs to the digits, so `-$42.35` rather than
  // `- $42.35`, and a positive amount starts with a character rather than a gap.
  return _tickerPattern.hasMatch(label)
      ? '$sign$digits $label'
      : '$sign$label$digits';
}

/// The grouped digits on their own, for somewhere the currency is already named.
///
/// An empty label is a sign rather than a ticker — nothing to put in front of
/// the digits, and no space left behind where it would have gone.
String formatAmountBare(int scaled) => formatAmountIn(scaled, '');

/// An exchange rate, trailing zeros trimmed so `1.500000` reads as `1.5`.
String formatRate(int scaled) {
  final whole = scaled ~/ rateScale;
  final fraction = (scaled % rateScale)
      .abs()
      .toString()
      .padLeft(6, '0')
      .replaceFirst(RegExp(r'0+$'), '');

  return fraction.isEmpty ? '$whole' : '$whole.$fraction';
}

/// The same digits with no symbol and no grouping, for seeding a text field.
///
/// Grouping separators would come straight back through `parseAmount`, which
/// treats a comma as a decimal point.
String formatAmountInput(int scaled) {
  final isNegative = scaled < 0;
  final absolute = scaled.abs();
  final major = absolute ~/ amountScale;
  final minor = (absolute % amountScale).toString().padLeft(2, '0');
  return '${isNegative ? '-' : ''}$major.$minor';
}
