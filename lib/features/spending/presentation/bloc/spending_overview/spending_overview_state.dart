part of 'spending_overview_bloc.dart';

enum SpendingOverviewStatus { initial, loading, success, failure }

final class SpendingOverviewState extends Equatable {
  const SpendingOverviewState({
    required this.month,
    this.status = SpendingOverviewStatus.initial,
    this.categories = const [],
    this.netTotalScaled = 0,
  });

  final SpendingOverviewStatus status;
  final List<CategorySpend> categories;

  /// Which month every figure here is for.
  ///
  /// Required rather than defaulted: a default would have to be "now", and a
  /// state that quietly reads the clock is one whose figures cannot be pinned
  /// down in a test.
  final CalendarMonth month;

  /// Income minus spending across every category, scaled by `amountScale`.
  ///
  /// Not derived from [categories]: this page shows one kind, and the net has
  /// to count both.
  final int netTotalScaled;

  /// Everything booked across the categories on this page.
  ///
  /// Signed, so a spending page's total is negative.
  int get totalScaled =>
      categories.fold(0, (sum, entry) => sum + entry.totalScaled);

  SpendingOverviewState copyWith({
    SpendingOverviewStatus? status,
    List<CategorySpend>? categories,
    CalendarMonth? month,
    int? netTotalScaled,
  }) {
    return SpendingOverviewState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      month: month ?? this.month,
      netTotalScaled: netTotalScaled ?? this.netTotalScaled,
    );
  }

  @override
  List<Object?> get props => [status, categories, month, netTotalScaled];
}
