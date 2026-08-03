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
