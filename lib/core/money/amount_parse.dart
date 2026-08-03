import 'package:my_pnl/core/money/scales.dart';

/// Parses typed input into a scaled integer, or null if it isn't a number.
///
/// Deliberately not `double.parse` followed by a multiply: `19.99 * 100` is
/// 1998.9999999999998 in binary floating point, and rounding that back is a
/// bug waiting to bite on some other value. The digits are read as integers
/// from the start.
///
/// Accepts either separator (`1.50`, `1,50`), at most [decimals] decimal
/// places, and an optional leading minus.
int? parseScaled(String input, {required int scale, required int decimals}) {
  final text = input.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;

  final match = RegExp(
    r'^(-)?(\d*)(?:\.(\d{0,'
    '$decimals'
    r'}))?$',
  ).firstMatch(text);
  if (match == null) return null;

  final major = match[2] ?? '';
  final minor = match[3] ?? '';
  if (major.isEmpty && minor.isEmpty) return null;

  final majorValue = major.isEmpty ? 0 : int.parse(major);
  final minorValue = minor.isEmpty
      ? 0
      : int.parse(minor.padRight(decimals, '0'));
  final value = majorValue * scale + minorValue;

  return match[1] == null ? value : -value;
}

/// Parses a cash amount, to two decimal places.
int? parseAmount(String input) =>
    parseScaled(input, scale: amountScale, decimals: 2);

/// Parses an exchange rate, to six decimal places.
int? parseRate(String input) =>
    parseScaled(input, scale: rateScale, decimals: 6);
