import 'package:bloc/bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';

/// Which month the overview is being read for.
///
/// Held above the pager rather than inside either page, for two reasons:
///
/// * income and spending are two halves of one book, so paging back on one has
///   to move the other — otherwise a swipe between them changes the month under
///   the reader without anything having been tapped;
/// * the toolbar sits above both pages and opens the sheets that list entries,
///   which have to be scoped to the month whose figures are on screen. From
///   inside a page that month is not reachable.
///
/// The pages keep their own [CalendarMonth] in `SpendingOverviewState` all the
/// same: that is what their queries are built from, and it follows this.
class SelectedMonthCubit extends Cubit<CalendarMonth> {
  SelectedMonthCubit({CalendarMonth? initial})
    : super(initial ?? CalendarMonth.now());

  void select(CalendarMonth month) {
    if (month == state) return;
    emit(month);
  }
}
