import 'package:equatable/equatable.dart';

/// One calendar month, as a year and a month rather than a date range.
///
/// UTC, matching how every timestamp is stored and how the ledger is already
/// grouped by `watchMonthlyPnl`. A device that moves between timezones then
/// keeps reporting the same figure for the same month.
class CalendarMonth extends Equatable {
  const CalendarMonth(this.year, this.month);

  /// The month [at] falls in, read in UTC.
  factory CalendarMonth.of(DateTime at) {
    final utc = at.toUtc();
    return CalendarMonth(utc.year, utc.month);
  }

  /// The month happening now.
  factory CalendarMonth.now() => CalendarMonth.of(DateTime.now());

  final int year;

  /// 1–12.
  final int month;

  /// The month after this one, rolling the year over at December.
  ///
  /// Built through [DateTime.utc], which normalizes a thirteenth month into
  /// January of the next year rather than holding a month nobody has.
  CalendarMonth get next => CalendarMonth.of(DateTime.utc(year, month + 1));

  /// The month before this one, rolling the year back at January.
  CalendarMonth get previous => CalendarMonth.of(DateTime.utc(year, month - 1));

  /// The first instant of the month, for formatting.
  DateTime get startsOn => DateTime(year, month);

  bool isAfter(CalendarMonth other) => ordinal > other.ordinal;

  bool isBefore(CalendarMonth other) => ordinal < other.ordinal;

  /// Months since year zero, so two of them can be compared as numbers.
  ///
  /// Public because SQL has to reach the same figure to compare a range of
  /// months: `year * 12 + month` over the stored timestamp is this arithmetic,
  /// and having one definition of it is what keeps a window computed here and
  /// applied there from disagreeing at a year boundary.
  int get ordinal => year * 12 + month;

  @override
  List<Object?> get props => [year, month];

  @override
  String toString() => 'CalendarMonth($year-$month)';
}
