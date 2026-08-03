import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_net_total.dart';

part 'spending_overview_event.dart';
part 'spending_overview_state.dart';

/// Drives the spending and income overview pages.
class SpendingOverviewBloc
    extends Bloc<SpendingOverviewEvent, SpendingOverviewState> {
  SpendingOverviewBloc({
    required WatchCategorySpend watchCategorySpend,
    WatchNetTotal? watchNetTotal,
    this.kind = CategoryKind.expense,
    CalendarMonth? initialMonth,
  }) : _watchCategorySpend = watchCategorySpend,
       _watchNetTotal = watchNetTotal,
       super(
         SpendingOverviewState(month: initialMonth ?? CalendarMonth.now()),
       ) {
    on<SpendingOverviewSubscriptionRequested>(
      _onSubscriptionRequested,
      // Restartable: a second request replaces the running subscription
      // instead of leaving two streams feeding the same state.
      transformer: restartable(),
    );
    on<SpendingOverviewNetTotalRequested>(
      _onNetTotalRequested,
      transformer: restartable(),
    );
    on<SpendingOverviewMonthChanged>(_onMonthChanged);
  }

  /// Null on pages that do not show a net figure, so they open no second
  /// query for a number nothing renders.
  final WatchNetTotal? _watchNetTotal;

  Future<void> _onNetTotalRequested(
    SpendingOverviewNetTotalRequested event,
    Emitter<SpendingOverviewState> emit,
  ) async {
    final watch = _watchNetTotal;
    if (watch == null) return;

    await emit.forEach<int>(
      watch(month: state.month),
      onData: (net) => state.copyWith(netTotalScaled: net),
      onError: (error, stackTrace) {
        log('Watching the net total failed', error: error,
            stackTrace: stackTrace);
        // Leaves the last known figure rather than showing a wrong zero.
        return state;
      },
    );
  }
  final WatchCategorySpend _watchCategorySpend;

  /// Which side of the ledger this instance shows. The spending and income
  /// pages are the same screen over different rows, so they share a bloc
  /// class and differ only in this.
  final CategoryKind kind;

  /// Points both queries at another month and shows it.
  ///
  /// The subscriptions are re-requested rather than filtered here: what a month
  /// comes to is a question for the database, and the running streams are for
  /// the month the user has left behind. Both handlers are restartable, so
  /// re-adding the events cancels those streams instead of stacking on them.
  void _onMonthChanged(
    SpendingOverviewMonthChanged event,
    Emitter<SpendingOverviewState> emit,
  ) {
    if (event.month == state.month) return;

    emit(state.copyWith(month: event.month));
    add(const SpendingOverviewSubscriptionRequested());
    add(const SpendingOverviewNetTotalRequested());
  }

  Future<void> _onSubscriptionRequested(
    SpendingOverviewSubscriptionRequested event,
    Emitter<SpendingOverviewState> emit,
  ) async {
    // Only on the way in. Paging between months re-runs this handler, and a
    // loading status there would drop a spinner over a grid that is about to
    // repopulate a frame later — the month's figures arrive from a local query.
    if (state.status != SpendingOverviewStatus.success) {
      emit(state.copyWith(status: SpendingOverviewStatus.loading));
    }

    await emit.forEach<List<CategorySpend>>(
      _watchCategorySpend(kind, month: state.month),
      onData: (categories) => state.copyWith(
        status: SpendingOverviewStatus.success,
        categories: categories,
      ),
      onError: (error, stackTrace) {
        // Logged because the state alone says only "failure", and a broken
        // watch query looks identical to an empty database on screen.
        log(
          'Watching category spend failed',
          error: error,
          stackTrace: stackTrace,
        );
        return state.copyWith(status: SpendingOverviewStatus.failure);
      },
    );
  }
}
