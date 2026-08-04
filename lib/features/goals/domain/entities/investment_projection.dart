import 'dart:math' as math;

import 'package:equatable/equatable.dart';

/// A what-if over the saved total: what it would earn if it were invested at
/// [annualPercent] a year and left alone for [years].
///
/// Not a record of anything. Nothing here is stored against the ledger, and both
/// figures are the reader's own assumptions — which is why they live together:
/// a rate means little without a stretch of time to apply it over.
class InvestmentProjection extends Equatable {
  const InvestmentProjection({
    required this.annualPercent,
    required this.years,
  });

  /// What the page opens on. Named rather than defaulted on the constructor, so
  /// every projection built elsewhere says out loud what it assumes.
  const InvestmentProjection.opening()
    : annualPercent = defaultPercent,
      years = defaultYears;

  /// What the page assumes until someone moves the rate slider.
  ///
  /// Five percent: about what a broad index fund has returned over the long run
  /// after inflation, so the opening projection is one the reader could plausibly
  /// have had rather than a sales pitch.
  static const defaultPercent = 5;

  /// Lowest rate the reader can assume. Roughly a savings account or a bond —
  /// below that the projection is indistinguishable from doing nothing.
  static const minPercent = 3;

  /// Highest rate the reader can assume. Well past what a market returns on
  /// average; there is no point offering a figure nobody could stand behind.
  static const maxPercent = 20;

  /// How far ahead the page looks until someone moves the years slider.
  ///
  /// Ten years, because compounding is the whole point and one year barely shows
  /// it — at 5% a decade adds most of another half to the money.
  static const defaultYears = 10;

  /// Shortest stretch worth projecting over.
  static const minYears = 1;

  /// Longest stretch worth projecting over. Fifty years is a working life; past
  /// that the figure is arithmetic rather than a plan.
  static const maxYears = 50;

  /// Days the annual rate is spread across.
  ///
  /// A flat 365 rather than a calendar year: the daily figure is a rate of
  /// earning, not a dated amount, and a leap year would move it for no reason
  /// the reader could see.
  static const daysPerYear = 365;

  /// The annual return being assumed, as a whole percentage.
  final int annualPercent;

  /// How long the money is assumed to be left invested, in whole years.
  final int years;

  /// The same assumptions held inside the ranges the sliders offer.
  ///
  /// Applied on the way in, so a figure from an older build or a rounding slip
  /// cannot put the projection somewhere the reader could not have chosen.
  InvestmentProjection get normalized => InvestmentProjection(
    annualPercent: annualPercent.clamp(minPercent, maxPercent),
    years: years.clamp(minYears, maxYears),
  );

  /// The daily rate that compounds to [annualPercent] over a year.
  ///
  /// The annual rate divided by 365 would be simple interest, which pays the
  /// same every day and undershoots what compounding actually gives. Taking the
  /// 365th root instead means 365 of these days come to exactly the annual
  /// figure.
  double get dailyRate =>
      math.pow(1 + annualPercent / 100, 1 / daysPerYear) - 1;

  /// What [savedScaled] grows to over [years], earnings included.
  ///
  /// The two places in the app that go through a double are here and [dailyRate],
  /// and deliberately: neither a 365th root nor a compounded power has an exact
  /// integer form. Both are rounded straight back to whole cents and never
  /// stored, so no error carries anywhere.
  int totalAfterOn(int savedScaled) =>
      savedScaled <= 0 ? 0 : (savedScaled * _growth).round();

  /// What [savedScaled] would earn over the whole of [years].
  ///
  /// Compounded, not multiplied: ten years at 5% is a little over 60% of the
  /// starting figure rather than 50%, and that gap is the reason the projection
  /// is worth showing at all. Exactly what [years] of [dailyRate] days come to.
  int profitOn(int savedScaled) =>
      savedScaled <= 0 ? 0 : (savedScaled * (_growth - 1)).round();

  /// What a single day earns today, before anything has compounded.
  ///
  /// The smallest the daily figure ever gets — every later day earns on a larger
  /// balance. Small balances round to nothing, which is the honest answer: a
  /// hundred dollars does not earn a cent a day.
  int dailyProfitTodayOn(int savedScaled) =>
      savedScaled <= 0 ? 0 : (savedScaled * dailyRate).round();

  /// What a single day earns once [years] have passed.
  ///
  /// The day's rate applied to the grown balance rather than to what is saved
  /// now — the point of compounding is that the same percentage is a larger
  /// amount every year, and a figure taken from today's balance hides that.
  int dailyProfitAfterOn(int savedScaled) =>
      savedScaled <= 0 ? 0 : (savedScaled * _growth * dailyRate).round();

  /// What a unit of money multiplies by over [years] at this rate.
  double get _growth => math.pow(1 + annualPercent / 100, years).toDouble();

  InvestmentProjection copyWith({int? annualPercent, int? years}) {
    return InvestmentProjection(
      annualPercent: annualPercent ?? this.annualPercent,
      years: years ?? this.years,
    );
  }

  @override
  List<Object?> get props => [annualPercent, years];
}
