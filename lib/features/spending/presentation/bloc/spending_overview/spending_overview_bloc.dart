import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/domain/usecases/reorder_categories.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_net_total.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_overrun_settings.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_spend_baselines.dart';

part 'spending_overview_event.dart';
part 'spending_overview_state.dart';

/// Drives the spending and income overview pages.
class SpendingOverviewBloc
    extends Bloc<SpendingOverviewEvent, SpendingOverviewState> {
  SpendingOverviewBloc({
    required WatchCategorySpend watchCategorySpend,
    WatchNetTotal? watchNetTotal,
    WatchSpendBaselines? watchSpendBaselines,
    WatchOverrunSettings? watchOverrunSettings,
    ReorderCategories? reorderCategories,
    this.kind = CategoryKind.expense,
    CalendarMonth? initialMonth,
  }) : _watchCategorySpend = watchCategorySpend,
       _watchNetTotal = watchNetTotal,
       _watchSpendBaselines = watchSpendBaselines,
       _watchOverrunSettings = watchOverrunSettings,
       _reorderCategories = reorderCategories,
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
    on<SpendingOverviewBaselinesRequested>(
      _onBaselinesRequested,
      transformer: restartable(),
    );
    on<SpendingOverviewSettingsRequested>(
      _onSettingsRequested,
      transformer: restartable(),
    );
    on<SpendingOverviewMonthChanged>(_onMonthChanged);
    // Sequential: two quick drags are two writes of the whole arrangement, and
    // letting them overlap would leave whichever finished last in charge.
    on<SpendingOverviewCategoryMoved>(
      _onCategoryMoved,
      transformer: sequential(),
    );
  }

  /// Null on pages that do not show a net figure, so they open no second
  /// query for a number nothing renders.
  final WatchNetTotal? _watchNetTotal;

  /// Null on pages that do not flag unusual months — the income page, where a
  /// month above the usual is good news and marking it red would be a lie.
  final WatchSpendBaselines? _watchSpendBaselines;

  /// Null where the grid is read-only, which is nowhere yet — the pages both
  /// pass it. Nullable all the same, so a bloc built for a test that never
  /// drags anything does not have to supply it.
  final ReorderCategories? _reorderCategories;

  /// Null alongside [_watchSpendBaselines]: thresholds are only of interest to
  /// a page that draws the flags. Null leaves the shipped defaults in state,
  /// which nothing then compares anything against.
  final WatchOverrunSettings? _watchOverrunSettings;

  /// Follows the reader's own thresholds, and whether they want warnings at all.
  ///
  /// Watched rather than read once: turning the warnings off has to clear the
  /// borders already on screen, not wait for the page to be opened again.
  Future<void> _onSettingsRequested(
    SpendingOverviewSettingsRequested event,
    Emitter<SpendingOverviewState> emit,
  ) async {
    final watch = _watchOverrunSettings;
    if (watch == null) return;

    await emit.forEach<OverrunSettings>(
      watch(),
      onData: (settings) => state.copyWith(settings: settings),
      onError: (error, stackTrace) {
        log(
          'Watching the overrun settings failed',
          error: error,
          stackTrace: stackTrace,
        );
        // Leaves the thresholds that were in force rather than falling back to
        // defaults the reader may have deliberately changed.
        return state;
      },
    );
  }

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
        log(
          'Watching the net total failed',
          error: error,
          stackTrace: stackTrace,
        );
        // Leaves the last known figure rather than showing a wrong zero.
        return state;
      },
    );
  }

  /// Watches what each category usually costs in a month.
  ///
  /// A failure here leaves the last known baselines and the page otherwise
  /// working: the flags are an annotation on figures that are correct without
  /// them, so losing the annotation is not worth an error screen over.
  Future<void> _onBaselinesRequested(
    SpendingOverviewBaselinesRequested event,
    Emitter<SpendingOverviewState> emit,
  ) async {
    final watch = _watchSpendBaselines;
    if (watch == null) return;

    await emit.forEach<Map<String, SpendBaseline>>(
      watch(kind, month: state.month),
      onData: (baselines) => state.copyWith(baselines: baselines),
      onError: (error, stackTrace) {
        log(
          'Watching spend baselines failed',
          error: error,
          stackTrace: stackTrace,
        );
        return state;
      },
    );
  }

  final WatchCategorySpend _watchCategorySpend;

  /// Which side of the ledger this instance shows. The spending and income
  /// pages are the same screen over different rows, so they share a bloc
  /// class and differ only in this.
  final CategoryKind kind;

  /// Points every query at another month and shows it.
  ///
  /// The subscriptions are re-requested rather than filtered here: what a month
  /// comes to is a question for the database, and the running streams are for
  /// the month the user has left behind. Every handler is restartable, so
  /// re-adding the events cancels those streams instead of stacking on them.
  ///
  /// The baselines go with them: they are the months before the one on screen,
  /// so paging back a month moves the window they average as well.
  void _onMonthChanged(
    SpendingOverviewMonthChanged event,
    Emitter<SpendingOverviewState> emit,
  ) {
    if (event.month == state.month) return;

    emit(state.copyWith(month: event.month));
    add(const SpendingOverviewSubscriptionRequested());
    add(const SpendingOverviewNetTotalRequested());
    add(const SpendingOverviewBaselinesRequested());
  }

  /// Moves a category and saves where the grid now stands.
  ///
  /// The new order is emitted before the write, not after it: the tile has to
  /// land where it was dropped, and waiting on storage would show it snap back
  /// for a frame first. The watch stream re-emits the saved order a moment
  /// later, which is also what puts the grid right if the write fails.
  Future<void> _onCategoryMoved(
    SpendingOverviewCategoryMoved event,
    Emitter<SpendingOverviewState> emit,
  ) async {
    final reorder = _reorderCategories;
    final categories = [...state.categories];

    final from = event.oldIndex;
    final to = event.newIndex;
    // A drop can name a cell the list no longer has: the grid is drawn from a
    // stream, and a category can be removed on another device between the lift
    // and the release.
    if (from == to ||
        from < 0 ||
        to < 0 ||
        from >= categories.length ||
        to >= categories.length) {
      return;
    }

    categories.insert(to, categories.removeAt(from));
    emit(state.copyWith(categories: categories));

    if (reorder == null) return;

    try {
      await reorder([for (final spend in categories) spend.category.id]);
    } on Exception catch (error, stackTrace) {
      // Nothing on screen to correct: the stream still holds the saved order
      // and re-emits it over this one.
      log(
        'Saving the category order failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
