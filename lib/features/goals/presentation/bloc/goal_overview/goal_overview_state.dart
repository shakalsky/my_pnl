part of 'goal_overview_bloc.dart';

enum GoalOverviewStatus { initial, loading, success, failure }

final class GoalOverviewState extends Equatable {
  const GoalOverviewState({
    this.status = GoalOverviewStatus.initial,
    this.months = const [],
    this.goal,
    this.errorMessage,
  });

  final GoalOverviewStatus status;

  /// Every month with entries, newest first — up and down alike.
  final List<MonthlyPnl> months;

  /// Null until a goal is set.
  final SavingsGoal? goal;

  /// A failed write or a goal that would not load. Separate from [status] so a
  /// transient error shows over the page rather than replacing it.
  final String? errorMessage;

  /// The months that made money, newest first.
  List<MonthlyPnl> get positiveMonths =>
      months.where((month) => month.isPositive).toList(growable: false);

  /// The months that ended down. Not counted towards the goal, but shown so the
  /// progress figure cannot be mistaken for what is in the bank.
  List<MonthlyPnl> get negativeMonths =>
      months.where((month) => month.isNegative).toList(growable: false);

  /// What the positive months add up to: the progress figure.
  int get savedScaled => _sum(positiveMonths);

  /// What the negative months add up to. Negative, or zero when there are none.
  int get lostScaled => _sum(negativeMonths);

  bool get hasGoal => goal != null;

  /// How far along the goal is, between 0 and 1. Zero without a goal, so a
  /// progress bar built from this reads empty rather than throwing.
  double get progress => goal?.progressOf(savedScaled) ?? 0;

  /// The same, rounded for display.
  int get progressPercent => (progress * 100).round();

  int get remainingScaled => goal?.remainingFrom(savedScaled) ?? 0;

  bool get isReached => goal?.isReachedBy(savedScaled) ?? false;

  int _sum(List<MonthlyPnl> months) =>
      months.fold(0, (total, month) => total + month.netScaled);

  GoalOverviewState copyWith({
    GoalOverviewStatus? status,
    List<MonthlyPnl>? months,
    SavingsGoal? goal,
    String? errorMessage,
    bool clearGoal = false,
    bool clearError = false,
  }) {
    return GoalOverviewState(
      status: status ?? this.status,
      months: months ?? this.months,
      goal: clearGoal ? null : goal ?? this.goal,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, months, goal, errorMessage];
}
