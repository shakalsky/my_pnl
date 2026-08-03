import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/amount_format.dart';

void main() {
  group('formatAmount', () {
    test('groups thousands and always shows both cents', () {
      expect(formatAmount(0), r'$0.00');
      expect(formatAmount(5), r'$0.05');
      expect(formatAmount(4235), r'$42.35');
      expect(formatAmount(123456789), r'$1,234,567.89');
    });

    test('puts the sign before the symbol', () {
      expect(formatAmount(-4235), r'-$42.35');
    });
  });

  group('formatAmountIn', () {
    test('leads with a one-character symbol', () {
      expect(formatAmountIn(3921, '€'), '€39.21');
      expect(formatAmountIn(-3921, '€'), '-€39.21');
    });

    test('leads with an emoji sign, however many parts it has', () {
      expect(formatAmountIn(3921, '🪙'), '🪙39.21');
      // Two runes, and still one sign.
      expect(formatAmountIn(3921, '🇪🇺'), '🇪🇺39.21');
      expect(formatAmountIn(-3921, '🪙'), '-🪙39.21');
    });

    test('leads with a symbol of more than one character', () {
      expect(formatAmountIn(3921, r'C$'), r'C$39.21');
    });

    test('follows the digits with a ticker', () {
      // 'SEK39.21' reads as one word rather than as an amount.
      expect(formatAmountIn(3921, 'SEK'), '39.21 SEK');
      expect(formatAmountIn(-3921, 'SEK'), '-39.21 SEK');
    });

    test('groups thousands the same as the base currency', () {
      expect(formatAmountIn(123456789, 'SEK'), '1,234,567.89 SEK');
    });
  });
}
