import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/goals/domain/entities/investment_projection.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/usecases/clear_goal.dart';
import 'package:my_pnl/features/goals/domain/usecases/watch_goal.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_monthly_pnl.dart';

part 'goal_overview_event.dart';
part 'goal_overview_state.dart';

/// Drives the goal page.
///
/// Two subscriptions rather than one combined stream: the months come from the
/// ledger and the target from the goal table, they change for unrelated
/// reasons, and merging them would make either change re-read both.
class GoalOverviewBloc extends Bloc<GoalOverviewEvent, GoalOverviewState> {
  GoalOverviewBloc({
    required WatchMonthlyPnl watchMonthlyPnl,
    required WatchGoal watchGoal,
    required ClearGoal clearGoal,
  }) : _watchMonthlyPnl = watchMonthlyPnl,
       _watchGoal = watchGoal,
       _clearGoal = clearGoal,
       super(const GoalOverviewState()) {
    on<GoalOverviewSubscriptionRequested>(
      _onSubscriptionRequested,
      // Restartable: a second request replaces the running subscription
      // instead of leaving two streams feeding the same state.
      transformer: restartable(),
    );
    on<GoalTargetSubscriptionRequested>(
      _onTargetSubscriptionRequested,
      transformer: restartable(),
    );
    on<GoalCleared>(_onCleared);
    on<GoalReturnRateChanged>(_onReturnRateChanged);
    on<GoalProjectionYearsChanged>(_onProjectionYearsChanged);
  }

  final WatchMonthlyPnl _watchMonthlyPnl;
  final WatchGoal _watchGoal;
  final ClearGoal _clearGoal;

  Future<void> _onSubscriptionRequested(
    GoalOverviewSubscriptionRequested event,
    Emitter<GoalOverviewState> emit,
  ) async {
    emit(state.copyWith(status: GoalOverviewStatus.loading));

    await emit.forEach<List<MonthlyPnl>>(
      _watchMonthlyPnl(),
      onData: (months) => state.copyWith(
        status: GoalOverviewStatus.success,
        months: months,
        clearError: true,
      ),
      onError: (error, stackTrace) {
        log(
          'Watching monthly P&L failed',
          error: error,
          stackTrace: stackTrace,
        );
        return state.copyWith(status: GoalOverviewStatus.failure);
      },
    );
  }

  /// The target only. A goal that fails to load leaves the months on screen —
  /// they are worth reading on their own, and the page offers to set a goal.
  Future<void> _onTargetSubscriptionRequested(
    GoalTargetSubscriptionRequested event,
    Emitter<GoalOverviewState> emit,
  ) async {
    await emit.forEach<SavingsGoal?>(
      _watchGoal(),
      onData: (goal) => goal == null
          ? state.copyWith(clearGoal: true)
          : state.copyWith(goal: goal),
      onError: (error, stackTrace) {
        log('Watching the goal failed', error: error, stackTrace: stackTrace);
        return state.copyWith(errorMessage: 'Could not load your goal');
      },
    );
  }

  Future<void> _onCleared(
    GoalCleared event,
    Emitter<GoalOverviewState> emit,
  ) async {
    try {
      await _clearGoal();
      // No emit on success: the watch stream carries the change, so there is
      // one source of truth for what the page shows.
    } on Object catch (e, s) {
      log('Clearing the goal failed', error: e, stackTrace: s);
      emit(state.copyWith(errorMessage: 'Could not remove your goal'));
    }
  }

  /// Nothing to write: the projection is a lens on the saved total, so it lives
  /// as long as the page does and touches no repository.
  void _onReturnRateChanged(
    GoalReturnRateChanged event,
    Emitter<GoalOverviewState> emit,
  ) {
    emit(
      state.copyWith(
        projection: state.projection
            .copyWith(annualPercent: event.annualPercent)
            .normalized,
      ),
    );
  }

  void _onProjectionYearsChanged(
    GoalProjectionYearsChanged event,
    Emitter<GoalOverviewState> emit,
  ) {
    emit(
      state.copyWith(
        projection: state.projection.copyWith(years: event.years).normalized,
      ),
    );
  }
}
