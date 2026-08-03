import 'package:equatable/equatable.dart';

/// What one calendar month came to: income minus spending.
///
/// Held as a year and a month rather than a [DateTime] range because that is
/// what the grouping produces and what callers ask about. The month is in UTC,
/// matching how every timestamp is stored — a device that moves between
/// timezones then keeps reporting the same figure for the same month.
class MonthlyPnl extends Equatable {
  const MonthlyPnl({
    required this.year,
    required this.month,
    required this.netScaled,
  });

  final int year;

  /// 1–12.
  final int month;

  /// Income minus spending for the month, scaled by `amountScale`. Negative
  /// when the month ended down.
  final int netScaled;

  /// A month that made money. Exactly zero counts as neither up nor down.
  bool get isPositive => netScaled > 0;

  bool get isNegative => netScaled < 0;

  /// The first instant of the month, for formatting.
  DateTime get startsOn => DateTime(year, month);

  @override
  List<Object?> get props => [year, month, netScaled];
}
