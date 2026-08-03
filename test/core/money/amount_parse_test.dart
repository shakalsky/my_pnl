import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/amount_parse.dart';

void main() {
  group('parseAmount', () {
    test('reads whole and fractional amounts', () {
      expect(parseAmount('0'), 0);
      expect(parseAmount('7'), 700);
      expect(parseAmount('12.5'), 1250);
      expect(parseAmount('12.05'), 1205);
      expect(parseAmount('1234.56'), 123456);
    });

    test('accepts a comma as the separator', () {
      expect(parseAmount('12,50'), 1250);
    });

    test('tolerates surrounding whitespace and a trailing separator', () {
      expect(parseAmount('  19.99  '), 1999);
      expect(parseAmount('19.'), 1900);
      expect(parseAmount('.5'), 50);
    });

    test('reads negatives', () {
      expect(parseAmount('-3.25'), -325);
    });

    test('avoids the floating point rounding trap', () {
      // (19.99 * 100).round() is fine, but 0.1 + 0.2 style error creeps in on
      // other values; parsing digits sidesteps the question entirely.
      expect(parseAmount('19.99'), 1999);
      expect(parseAmount('8.29'), 829);
      expect(parseAmount('1.15'), 115);
    });

    test('rejects anything that is not an amount', () {
      expect(parseAmount(''), isNull);
      expect(parseAmount('   '), isNull);
      expect(parseAmount('.'), isNull);
      expect(parseAmount('-'), isNull);
      expect(parseAmount('abc'), isNull);
      expect(parseAmount('1.234'), isNull, reason: 'three decimal places');
      expect(parseAmount('1 000'), isNull);
      expect(parseAmount('1.2.3'), isNull);
    });
  });
}
