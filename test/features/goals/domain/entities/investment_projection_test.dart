import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/goals/domain/entities/investment_projection.dart';

void main() {
  group('InvestmentProjection', () {
    test('assumes five percent over ten years until told otherwise', () {
      expect(InvestmentProjection.defaultPercent, 5);
      expect(InvestmentProjection.defaultYears, 10);
    });

    test('offers 3 to 20 percent over 1 to 50 years', () {
      expect(InvestmentProjection.minPercent, 3);
      expect(InvestmentProjection.maxPercent, 20);
      expect(InvestmentProjection.minYears, 1);
      expect(InvestmentProjection.maxYears, 50);
    });

    test('compounds a day rather than dividing the year', () {
      const projection = InvestmentProjection(annualPercent: 5, years: 10);

      // Simple interest would be 5% / 365 = 1.3699e-4. Compounding gives less
      // per day, because each day earns on the days before it.
      expect(projection.dailyRate, lessThan(0.05 / 365));
      expect(projection.dailyRate, closeTo(0.000133681, 1e-9));
    });

    test('gives the daily gain in whole cents', () {
      // 3000 at 5% earns 40.1 cents on day one.
      expect(
        const InvestmentProjection(
          annualPercent: 5,
          years: 10,
        ).dailyProfitTodayOn(300000),
        40,
      );
      expect(
        const InvestmentProjection(
          annualPercent: 20,
          years: 10,
        ).dailyProfitTodayOn(300000),
        150,
      );
      expect(
        const InvestmentProjection(
          annualPercent: 3,
          years: 10,
        ).dailyProfitTodayOn(300000),
        24,
      );
    });

    test(
      "today's daily gain does not depend on how long the money is left",
      () {
        const short = InvestmentProjection(annualPercent: 5, years: 1);
        const long = InvestmentProjection(annualPercent: 5, years: 50);

        expect(
          short.dailyProfitTodayOn(300000),
          long.dailyProfitTodayOn(300000),
        );
      },
    );

    test('the daily gain later is the same rate on the grown balance', () {
      const projection = InvestmentProjection(annualPercent: 5, years: 10);

      // 3000 grows to 4,886.68 over ten years, and a day of that earns 65
      // cents where today it earns 40.
      expect(projection.totalAfterOn(300000), 488668);
      expect(projection.dailyProfitAfterOn(300000), 65);
      expect(projection.dailyProfitTodayOn(300000), 40);
    });

    test('the longer it is left, the more a single day earns', () {
      var previous = 0;

      for (var years = 1; years <= InvestmentProjection.maxYears; years++) {
        final daily = InvestmentProjection(
          annualPercent: 5,
          years: years,
        ).dailyProfitAfterOn(300000);

        expect(daily, greaterThan(previous));
        previous = daily;
      }

      // Fifty years in, a day earns 4.60 rather than today's 40 cents.
      expect(previous, 460);
    });

    test('a higher rate earns more on the day, later', () {
      expect(
        const InvestmentProjection(
          annualPercent: 20,
          years: 10,
        ).dailyProfitAfterOn(300000),
        928,
      );
      expect(
        const InvestmentProjection(
          annualPercent: 3,
          years: 10,
        ).dailyProfitAfterOn(300000),
        33,
      );
    });

    test('what is in the pot is what was saved plus what it earned', () {
      const projection = InvestmentProjection(annualPercent: 12, years: 30);

      expect(
        projection.totalAfterOn(300000),
        300000 + projection.profitOn(300000),
      );
    });

    test('a balance too small to earn a cent a day earns nothing a day', () {
      const projection = InvestmentProjection(annualPercent: 5, years: 10);

      expect(projection.dailyProfitTodayOn(10000), 1);
      expect(projection.dailyProfitTodayOn(1000), 0);
      // ...but the years still say what the rate is worth: 10 dollars grows by
      // 6.29 over the default ten.
      expect(projection.profitOn(1000), 629);
    });

    test('compounds the years rather than multiplying one of them', () {
      // 3000 at 5% for ten years: 1.05^10 is 1.6289, so 1,886.68 earned —
      // where ten simple years would give exactly half the starting figure.
      expect(const InvestmentProjection.opening().profitOn(300000), 188668);
      expect(
        const InvestmentProjection.opening().profitOn(300000),
        greaterThan(150000),
      );
      expect(
        const InvestmentProjection(annualPercent: 5, years: 1).profitOn(300000),
        15000,
      );
      expect(
        const InvestmentProjection(
          annualPercent: 20,
          years: 10,
        ).profitOn(300000),
        1557521,
      );
    });

    test('a longer stretch earns more', () {
      const rate = 5;
      var previous = 0;

      for (var years = 1; years <= InvestmentProjection.maxYears; years++) {
        final earned = InvestmentProjection(
          annualPercent: rate,
          years: years,
        ).profitOn(300000);

        expect(earned, greaterThan(previous));
        previous = earned;
      }
    });

    test('the days and the years agree', () {
      const projection = InvestmentProjection(annualPercent: 7, years: 10);
      var balance = 100000.0;

      for (var year = 0; year < projection.years; year++) {
        for (var day = 0; day < InvestmentProjection.daysPerYear; day++) {
          balance += balance * projection.dailyRate;
        }
      }

      expect(balance - 100000, closeTo(projection.profitOn(100000), 1));
    });

    test('nothing saved earns nothing', () {
      const projection = InvestmentProjection.opening();

      expect(projection.dailyProfitTodayOn(0), 0);
      expect(projection.dailyProfitAfterOn(0), 0);
      expect(projection.profitOn(0), 0);
      expect(projection.totalAfterOn(0), 0);
    });

    test('a negative total is not turned into a gain', () {
      const projection = InvestmentProjection.opening();

      expect(projection.dailyProfitTodayOn(-300000), 0);
      expect(projection.dailyProfitAfterOn(-300000), 0);
      expect(projection.profitOn(-300000), 0);
      expect(projection.totalAfterOn(-300000), 0);
    });

    test('normalizing holds both figures inside the ranges on offer', () {
      expect(
        const InvestmentProjection(annualPercent: 0, years: 0).normalized,
        const InvestmentProjection(annualPercent: 3, years: 1),
      );
      expect(
        const InvestmentProjection(annualPercent: 900, years: 900).normalized,
        const InvestmentProjection(annualPercent: 20, years: 50),
      );
      expect(
        const InvestmentProjection(annualPercent: 12, years: 30).normalized,
        const InvestmentProjection(annualPercent: 12, years: 30),
      );
    });

    test('copying leaves the other assumption alone', () {
      const projection = InvestmentProjection(annualPercent: 12, years: 30);

      expect(projection.copyWith(years: 5).annualPercent, 12);
      expect(projection.copyWith(annualPercent: 4).years, 30);
    });

    test('is its assumptions', () {
      expect(
        const InvestmentProjection(annualPercent: 5, years: 10),
        const InvestmentProjection.opening(),
      );
      expect(
        const InvestmentProjection(annualPercent: 5, years: 10),
        isNot(const InvestmentProjection(annualPercent: 5, years: 11)),
      );
    });
  });
}
