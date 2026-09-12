part of 'goal_overview_bloc.dart';

enum GoalOverviewStatus { initial, loading, success, failure }

final class GoalOverviewState extends Equatable {
  const GoalOverviewState({
    this.status = GoalOverviewStatus.initial,
    this.months = const [],
    this.goal,
    this.projection = const InvestmentProjection.opening(),
    this.errorMessage,
  });

  final GoalOverviewStatus status;

  /// Every month with entries, newest first — up and down alike.
  final List<MonthlyPnl> months;

  /// Null until a goal is set.
  final SavingsGoal? goal;

  /// The return and stretch of time the reader is assuming for the what-if
  /// figures. Not saved anywhere: a way of reading the total, not part of it.
  final InvestmentProjection projection;

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

  /// What was already put aside before the app started counting, or zero when
  /// there is no goal to have recorded it.
  int get startingAmountScaled => goal?.startingAmountScaled ?? 0;

  /// The pot: what was already there plus what the positive months added.
  ///
  /// One figure rather than two, because it is one pot — the reader's savings
  /// do not split by whether this app watched them arrive, and a progress bar
  /// that left half of them out would understate a goal already met.
  int get savedScaled => startingAmountScaled + _sum(positiveMonths);

  /// What the months alone add up to. Only worth showing beside
  /// [startingAmountScaled], to say where the total came from.
  int get monthsSavedScaled => _sum(positiveMonths);

  /// What the negative months add up to. Negative, or zero when there are none.
  int get lostScaled => _sum(negativeMonths);

  bool get hasGoal => goal != null;

  bool get hasStartingAmount => startingAmountScaled > 0;

  /// How far along the goal is, between 0 and 1. Zero without a goal, so a
  /// progress bar built from this reads empty rather than throwing.
  double get progress => goal?.progressOf(savedScaled) ?? 0;

  /// The same, rounded for display.
  int get progressPercent => (progress * 100).round();

  int get remainingScaled => goal?.remainingFrom(savedScaled) ?? 0;

  bool get isReached => goal?.isReachedBy(savedScaled) ?? false;

  /// What the saved total would earn in a day once [projection]'s years have
  /// passed — the day's rate on the balance by then, not on today's.
  int get dailyProfitLaterScaled => projection.dailyProfitAfterOn(savedScaled);

  /// What it would earn across the whole of those years.
  int get longRunProfitScaled => projection.profitOn(savedScaled);

  /// What it would be worth by then, earnings included.
  int get totalLaterScaled => projection.totalAfterOn(savedScaled);

  int _sum(List<MonthlyPnl> months) =>
      months.fold(0, (total, month) => total + month.netScaled);

  GoalOverviewState copyWith({
    GoalOverviewStatus? status,
    List<MonthlyPnl>? months,
    SavingsGoal? goal,
    InvestmentProjection? projection,
    String? errorMessage,
    bool clearGoal = false,
    bool clearError = false,
  }) {
    return GoalOverviewState(
      status: status ?? this.status,
      months: months ?? this.months,
      goal: clearGoal ? null : goal ?? this.goal,
      projection: projection ?? this.projection,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, months, goal, projection, errorMessage];
}
