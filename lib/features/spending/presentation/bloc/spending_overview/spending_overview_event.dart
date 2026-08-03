part of 'spending_overview_bloc.dart';

sealed class SpendingOverviewEvent extends Equatable {
  const SpendingOverviewEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching categories. Re-adding it restarts the subscription.
final class SpendingOverviewSubscriptionRequested
    extends SpendingOverviewEvent {
  const SpendingOverviewSubscriptionRequested();
}

/// Starts watching income minus spending. A second subscription because the
/// net counts both kinds, while the list shows one.
final class SpendingOverviewNetTotalRequested extends SpendingOverviewEvent {
  const SpendingOverviewNetTotalRequested();
}

/// Shows another month. Both totals are re-read for it.
final class SpendingOverviewMonthChanged extends SpendingOverviewEvent {
  const SpendingOverviewMonthChanged(this.month);

  final CalendarMonth month;

  @override
  List<Object?> get props => [month];
}
