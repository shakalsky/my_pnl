import 'package:equatable/equatable.dart';

/// How far past its usual a category's month has gone.
///
/// Steps rather than a raw ratio, because what reads this draws one of a fixed
/// set of borders. Declared in order of severity, so [index] compares them.
enum SpendOverrun {
  /// Within the usual — or nothing to compare against yet.
  none,

  /// Noticeably up on the usual month.
  mild,

  /// Half again as much as usual, or more.
  high,

  /// Twice the usual month, or more.
  severe
  ;

  bool get isFlagged => this != SpendOverrun.none;
}

/// What one category usually costs in a month.
///
/// A magnitude and the number of months behind it, kept together because the
/// average alone cannot say whether it is worth trusting: one month of history
/// is a figure, not a habit, and flagging against it would call every second
/// month of a new category an overrun.
class SpendBaseline extends Equatable {
  const SpendBaseline({required this.averageScaled, required this.months});

  /// The average month, scaled by `amountScale`.
  ///
  /// Always a magnitude, so it can be compared with either side of the ledger
  /// without the caller knowing that spending is stored negative.
  final int averageScaled;

  /// How many months the average is over.
  ///
  /// Only months with something booked in them count: a month before the
  /// category existed is not a month it cost nothing, and averaging those in
  /// would drag every usual figure towards zero and flag ordinary spending.
  final int months;

  /// How far back a baseline reaches.
  ///
  /// Half a year: long enough to average out a quiet month or a double
  /// payment, short enough that what someone spent two years ago has no say in
  /// whether this month is unusual.
  static const lookbackMonths = 6;

  /// Fewest months worth comparing a figure against.
  static const minimumMonths = 2;

  /// Whether there is enough here to call a month unusual.
  ///
  /// A zero average is excluded as well as a thin one: every figure is
  /// infinitely more than nothing, so the comparison has no scale to it.
  bool get isComparable => months >= minimumMonths && averageScaled > 0;

  /// [spentScaled] as a percentage of the average — 250 meaning two and a half
  /// times the usual month. Null when there is nothing to compare against.
  ///
  /// Where that percentage becomes a warning is not decided here: the
  /// thresholds are the reader's setting, and `OverrunSettings.overrunFor`
  /// applies them.
  ///
  /// Integer arithmetic throughout, like every other figure in the app: the
  /// multiplication comes before the division, so the percentage is exact
  /// rather than the rounding of a ratio.
  int? percentOf(int spentScaled) =>
      isComparable ? spentScaled.abs() * 100 ~/ averageScaled : null;

  @override
  List<Object?> get props => [averageScaled, months];

  @override
  String toString() => 'SpendBaseline($averageScaled over $months months)';
}
