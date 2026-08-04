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

/// Starts watching what each category usually costs in a month.
///
/// A third subscription because it answers a different question from the other
/// two: they are about the month on screen, this one about the months before
/// it, and only the comparison of the two can call a month unusual.
final class SpendingOverviewBaselinesRequested extends SpendingOverviewEvent {
  const SpendingOverviewBaselinesRequested();
}

/// Starts watching the reader's warning thresholds.
///
/// Separate from the baselines because the two change for different reasons and
/// on different clocks: the months before this one change when money is
/// recorded, the thresholds when someone opens the settings.
final class SpendingOverviewSettingsRequested extends SpendingOverviewEvent {
  const SpendingOverviewSettingsRequested();
}

/// Shows another month. Both totals are re-read for it.
final class SpendingOverviewMonthChanged extends SpendingOverviewEvent {
  const SpendingOverviewMonthChanged(this.month);

  final CalendarMonth month;

  @override
  List<Object?> get props => [month];
}
