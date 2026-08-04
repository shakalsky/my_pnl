import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';

/// A usual month of 100.00, over enough months to be worth comparing against.
const _usual = SpendBaseline(averageScaled: 10000, months: 4);

void main() {
  group('SpendBaseline', () {
    test('reads a figure as a percentage of the usual month', () {
      expect(_usual.percentOf(-15000), 150);
    });

    test('reads either sign the same way', () {
      // Spending is stored negative and income positive; a baseline is a
      // magnitude, so it must not care which side of the ledger it is given.
      expect(_usual.percentOf(-12500), _usual.percentOf(12500));
    });

    test('divides after multiplying, so the percentage is exact', () {
      // 33.33 of a usual 100.00. Dividing first would round the ratio to 0 and
      // report every month as nothing.
      expect(_usual.percentOf(-3333), 33);
    });

    test('says nothing on one month of history', () {
      const oneMonth = SpendBaseline(averageScaled: 10000, months: 1);

      // A single month is a figure, not a habit: comparing against it would
      // call the second month of every new category an overrun.
      expect(oneMonth.isComparable, isFalse);
      expect(oneMonth.percentOf(-50000), isNull);
    });

    test('says nothing against an average of nothing', () {
      const nothing = SpendBaseline(averageScaled: 0, months: 4);

      // Every figure is infinitely more than zero, so there is no scale to the
      // comparison and nothing worth colouring a border over.
      expect(nothing.isComparable, isFalse);
      expect(nothing.percentOf(-1), isNull);
    });

    test('orders its steps by severity', () {
      // What reads this picks a colour per step, so the order is part of the
      // contract rather than an accident of how they were typed.
      expect(SpendOverrun.values, [
        SpendOverrun.none,
        SpendOverrun.mild,
        SpendOverrun.high,
        SpendOverrun.severe,
      ]);
      expect(SpendOverrun.none.isFlagged, isFalse);
      expect(SpendOverrun.values.where((step) => step.isFlagged), hasLength(3));
    });

    test('is equal to another baseline of the same figures', () {
      expect(
        const SpendBaseline(averageScaled: 10000, months: 4),
        const SpendBaseline(averageScaled: 10000, months: 4),
      );
    });
  });
}
