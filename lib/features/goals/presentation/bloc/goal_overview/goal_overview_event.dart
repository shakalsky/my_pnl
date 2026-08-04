part of 'goal_overview_bloc.dart';

sealed class GoalOverviewEvent extends Equatable {
  const GoalOverviewEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching what each month came to.
final class GoalOverviewSubscriptionRequested extends GoalOverviewEvent {
  const GoalOverviewSubscriptionRequested();
}

/// Starts watching the target being saved towards.
final class GoalTargetSubscriptionRequested extends GoalOverviewEvent {
  const GoalTargetSubscriptionRequested();
}

final class GoalCleared extends GoalOverviewEvent {
  const GoalCleared();
}

/// The reader moved the assumed return under the what-if figure.
final class GoalReturnRateChanged extends GoalOverviewEvent {
  const GoalReturnRateChanged(this.annualPercent);

  final int annualPercent;

  @override
  List<Object?> get props => [annualPercent];
}

/// The reader moved how far ahead the what-if figure looks.
final class GoalProjectionYearsChanged extends GoalOverviewEvent {
  const GoalProjectionYearsChanged(this.years);

  final int years;

  @override
  List<Object?> get props => [years];
}
