import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/conversion.dart';
import 'package:my_pnl/core/money/scales.dart';

/// Rates as the currencies sheet stores them: what one unit is worth in USD.
const _euro = 1080000; // 1 EUR = 1.08 USD
const _minor = 23; // 1 unit = 0.000023 USD

void main() {
  group('convertFromBase', () {
    test('divides by the rate rather than multiplying by it', () {
      // $42.35 at 1.08 to the euro is €39.21, not €45.74.
      expect(
        convertFromBase(amountScaled: 4235, exchangeRateScaled: _euro),
        3921,
      );
    });

    test('leaves an amount alone at parity', () {
      expect(
        convertFromBase(amountScaled: 4235, exchangeRateScaled: rateScale),
        4235,
      );
    });

    test('multiplies up against a currency worth less than the base', () {
      // The case the currencies sheet's own example describes.
      expect(
        convertFromBase(amountScaled: 4235, exchangeRateScaled: _minor),
        184130435,
      );
    });

    test('rounds to the nearer cent', () {
      // $1.00 into thirds is 33.33 units, which rounds down...
      expect(
        convertFromBase(amountScaled: 100, exchangeRateScaled: 3000000),
        33,
      );
      // ...and 66.67 rounds up rather than truncating to 66.
      expect(
        convertFromBase(amountScaled: 200, exchangeRateScaled: 3000000),
        67,
      );
    });

    test('rounds the same either side of zero', () {
      const rate = 3000000;

      expect(
        convertFromBase(amountScaled: -200, exchangeRateScaled: rate),
        -convertFromBase(amountScaled: 200, exchangeRateScaled: rate),
      );
    });

    test('keeps a negative total negative', () {
      expect(
        convertFromBase(amountScaled: -4235, exchangeRateScaled: _euro),
        -3921,
      );
    });

    test('converts zero to zero', () {
      expect(convertFromBase(amountScaled: 0, exchangeRateScaled: _euro), 0);
    });

    test('holds precision on a large total', () {
      // A million dollars, well inside what 64-bit integer maths allows here.
      expect(
        convertFromBase(amountScaled: 100000000, exchangeRateScaled: _euro),
        92592593,
      );
    });

    test('refuses a rate that cannot be divided by', () {
      for (final rate in [0, -1, -1080000]) {
        expect(
          () => convertFromBase(amountScaled: 100, exchangeRateScaled: rate),
          throwsArgumentError,
          reason: '$rate',
        );
      }
    });
  });
}
