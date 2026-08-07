import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/core/money/scales.dart';

void main() {
  // The base is one value for the whole process, so a test that changes it puts
  // it back or the next one inherits it.
  tearDown(() => setActiveBaseCurrency(BaseCurrency.usd));

  group('BaseCurrency', () {
    test('accepts a ticker of the shape a currency has', () {
      expect(BaseCurrency.usd.isValid, isTrue);
      expect(const BaseCurrency(ticker: 'PLN', symbol: 'zł').isValid, isTrue);
      // Ten characters, and digits are allowed — the same rule as a currency
      // the user adds.
      expect(
        const BaseCurrency(ticker: 'GOLD1OUNCE', symbol: '🪙').isValid,
        isTrue,
      );
    });

    test('refuses one nothing could be labelled with', () {
      expect(const BaseCurrency(ticker: '', symbol: r'$').isValid, isFalse);
      expect(const BaseCurrency(ticker: 'E', symbol: '€').isValid, isFalse);
      expect(const BaseCurrency(ticker: 'usd', symbol: r'$').isValid, isFalse);
      expect(const BaseCurrency(ticker: 'US D', symbol: r'$').isValid, isFalse);
      expect(
        const BaseCurrency(ticker: 'ELEVENCHARS', symbol: r'$').isValid,
        isFalse,
      );
      expect(const BaseCurrency(ticker: 'EUR', symbol: '').isValid, isFalse);
    });
  });

  group('the active base currency', () {
    test('starts on the currency the app ships with', () {
      expect(activeBaseCurrency, BaseCurrency.usd);
      expect(baseCurrency, 'USD');
      expect(baseCurrencySymbol, r'$');
    });

    test('is what every figure is labelled with', () {
      setActiveBaseCurrency(
        const BaseCurrency(ticker: 'PLN', symbol: 'zł'),
      );

      expect(baseCurrency, 'PLN');
      expect(formatAmount(4235), 'zł42.35');
      // The figure itself is untouched: only the sign in front of it changes.
      expect(formatAmount(-123456789), '-zł1,234,567.89');
    });

    test('takes a ticker as its own sign', () {
      setActiveBaseCurrency(
        const BaseCurrency(ticker: 'SEK', symbol: 'SEK'),
      );

      // A ticker follows the digits wherever it is used as a label.
      expect(formatAmount(3921), '39.21 SEK');
    });

    test('refuses a currency nothing could be labelled with', () {
      setActiveBaseCurrency(const BaseCurrency(ticker: '', symbol: ''));

      expect(
        activeBaseCurrency,
        BaseCurrency.usd,
        reason: 'a malformed preference leaves the base as it was',
      );
    });
  });
}
