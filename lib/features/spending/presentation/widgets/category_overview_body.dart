import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';
import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';
import 'package:my_pnl/features/currencies/domain/usecases/read_display_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/save_display_currency.dart';
import 'package:my_pnl/features/currencies/domain/usecases/watch_currencies.dart';
import 'package:my_pnl/features/currencies/presentation/bloc/display_currency/display_currency_bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';
import 'package:my_pnl/features/spending/presentation/widgets/amount_entry_sheet.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_form_sheet.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_tile.dart';
import 'package:my_pnl/features/spending/presentation/widgets/total_circle.dart';

/// Total in a circle, categories in a grid beneath it.
///
/// Shared by the spending and income pages: the two differ in which rows they
/// load and what the total is called, not in how any of it behaves.
class CategoryOverviewBody extends StatelessWidget {
  const CategoryOverviewBody({
    required this.state,
    required this.kind,
    required this.totalLabel,
    this.totalScaled,
    super.key,
  });

  final SpendingOverviewState state;
  final CategoryKind kind;
  final String totalLabel;

  /// What the circle shows. Defaults to this page's own categories; the
  /// spending page passes the net instead.
  final int? totalScaled;

  /// The ring around the total: one slice per category, in its own colour.
  ///
  /// Built from the categories rather than from [totalScaled], because the two
  /// are not the same figure — the spending page's headline is income minus
  /// spending, which the slices here are no part of. The ring answers "where
  /// did it go", the number answers "what is left".
  List<TotalCircleSegment> get _segments => [
    for (final spend in state.categories)
      if (spend.totalScaled != 0)
        TotalCircleSegment(
          color: Color(spend.category.colorArgb),
          weightScaled: spend.totalScaled.abs(),
        ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      // Provided here rather than by each page, so both sides of the ledger
      // read their totals the same way. Created once per open: rebuilding this
      // widget reuses its element, and with it the bloc.
      create: (context) => DisplayCurrencyBloc(
        watchCurrencies: WatchCurrencies(context.read<CurrencyRepository>()),
        readDisplayCurrency: ReadDisplayCurrency(
          context.read<DisplayCurrencyStore>(),
        ),
        saveDisplayCurrency: SaveDisplayCurrency(
          context.read<DisplayCurrencyStore>(),
        ),
      )..add(const DisplayCurrencySubscriptionRequested()),
      // One builder over the whole page, not one per figure: the circle and
      // every tile have to read in the same currency, and a shared builder is
      // what guarantees they cannot fall out of step.
      child: BlocBuilder<DisplayCurrencyBloc, DisplayCurrencyState>(
        builder: (context, currency) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final diameter = math.min<double>(
                constraints.maxWidth * 0.55,
                200,
              );

              return Column(
                children: [
                  _MonthHeader(month: state.month),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _MonthStep(
                        icon: Icons.chevron_left,
                        tooltip: 'Previous month',
                        month: state.month.previous,
                      ),
                      SizedBox(
                        width: diameter,
                        height: diameter,
                        child: TotalCircle(
                          // Only the figures convert. The ring is made of shares
                          // of a whole, and a share is the same fraction
                          // whatever currency it is counted in.
                          totalScaled: currency.convert(
                            totalScaled ?? state.totalScaled,
                          ),
                          label: totalLabel,
                          currencyLabel: currency.label,
                          segments: _segments,
                          // Inert until there is a second currency to show, so a
                          // tap that could do nothing does not pretend
                          // otherwise.
                          onTap: currency.canCycle
                              ? () => context.read<DisplayCurrencyBloc>().add(
                                  const DisplayCurrencyCycled(),
                                )
                              : null,
                        ),
                      ),
                      _MonthStep(
                        icon: Icons.chevron_right,
                        tooltip: 'Next month',
                        // Nothing can be booked in a month that has not
                        // happened, so forward stops at the present rather than
                        // walking off into empty months.
                        month: state.month.isBefore(CalendarMonth.now())
                            ? state.month.next
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      physics: const _ScrollOnlyWhenNeeded(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisExtent: 104,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                      // The add tile is the last cell, so it stays in flow as
                      // categories are added rather than needing a reserved
                      // spot.
                      itemCount: state.categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == state.categories.length) {
                          return _ReorderableCell(
                            // Nothing to pick up here, but it is still a place
                            // to let go: the add tile is the cell past the last
                            // category, so dropping on it means "make this the
                            // last one".
                            index: index,
                            dropsAt: state.categories.length - 1,
                            draggable: false,
                            child: AddCategoryTile(
                              onPressed: () => CategoryFormSheet.showCreate(
                                context,
                                kind: kind,
                              ),
                            ),
                          );
                        }

                        final spend = state.categories[index];
                        return _ReorderableCell(
                          index: index,
                          dropsAt: index,
                          child: CategoryTile(
                            spend: spend,
                            totalScaled: currency.convert(spend.totalScaled),
                            currencyLabel: currency.label,
                            // Worked out from the unconverted figures: a rate
                            // applies to both sides of the comparison and
                            // cancels out, so converting first could only
                            // introduce rounding into which colour the border
                            // gets.
                            overrun: state.overrunFor(spend),
                            onAddAmount: () =>
                                AmountEntrySheet.show(context, spend.category),
                            onEdit: () => CategoryFormSheet.showEdit(
                              context,
                              spend.category,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// One cell of the grid, which can be picked up and dropped on another.
///
/// A long press lifts the tile — the gesture the tile itself has given up for
/// this — and dropping it on another cell takes that cell's place, shuffling
/// the ones in between along. The arrangement is saved by the bloc, so it
/// survives the page being closed and reaches the reader's other devices.
///
/// Built by hand rather than with a reorderable list: Flutter has no
/// reorderable grid, and the drag here is cell-to-cell rather than a slot
/// opening up as the finger moves, which is what a four-across grid of small
/// tiles can show without the whole thing reflowing under the finger.
class _ReorderableCell extends StatelessWidget {
  const _ReorderableCell({
    required this.index,
    required this.dropsAt,
    required this.child,
    this.draggable = true,
  });

  /// This cell's place in the grid, which is what a drag from it carries.
  final int index;

  /// Where a category dropped here ends up. The same as [index] for a category
  /// cell; the last place for the add tile, which sits past the end.
  final int dropsAt;

  /// False for a cell that is somewhere to drop but nothing to pick up.
  final bool draggable;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return DragTarget<int>(
      // A tile dropped where it already is changes nothing, and highlighting
      // its own cell would say otherwise.
      onWillAcceptWithDetails: (details) => details.data != dropsAt,
      onAcceptWithDetails: (details) =>
          context.read<SpendingOverviewBloc>().add(
            SpendingOverviewCategoryMoved(
              oldIndex: details.data,
              newIndex: dropsAt,
            ),
          ),
      builder: (context, candidates, _) {
        // Drawn over the cell rather than around it: the grid hands out exactly
        // the space a tile fills, so an outline in the layout would have to come
        // out of the tile's own width and shift everything inside it.
        final cell = Container(
          foregroundDecoration: candidates.isEmpty
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary, width: 2),
                ),
          child: child,
        );

        if (!draggable) return cell;

        // The cell's own size, because a dragged tile follows the finger outside
        // the grid, where nothing constrains it any more.
        return LayoutBuilder(
          builder: (context, constraints) => LongPressDraggable<int>(
            data: index,
            feedback: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: Opacity(opacity: 0.9, child: child),
            ),
            // Left in place and faded rather than removed: a hole in a grid
            // pulls every tile after it back a place, which is the whole list
            // moving to show one tile being lifted.
            childWhenDragging: Opacity(opacity: 0.3, child: child),
            child: cell,
          ),
        );
      },
    );
  }
}

/// Which month the figures below are for.
class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.month});

  final CalendarMonth month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      // Month and year together: paged back far enough, "January" alone stops
      // saying which January.
      DateFormat.yMMMM().format(month.startsOn),
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

/// One of the arrows either side of the circle.
///
/// [month] is where it goes; null leaves the arrow disabled, which is how the
/// forward one spends the current month.
class _MonthStep extends StatelessWidget {
  const _MonthStep({
    required this.icon,
    required this.tooltip,
    required this.month,
  });

  final IconData icon;
  final String tooltip;
  final CalendarMonth? month;

  @override
  Widget build(BuildContext context) {
    final target = month;

    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: target == null
          ? null
          : () => context.read<SpendingOverviewBloc>().add(
              SpendingOverviewMonthChanged(target),
            ),
    );
  }
}

/// Platform scroll physics, minus the drag when there is nothing to scroll.
///
/// [BouncingScrollPhysics] accepts a drag unconditionally, so on iOS a grid
/// of four tiles still rubber-bands away from the top and settles back. This
/// keeps the bounce for a grid that genuinely overflows and refuses the drag
/// otherwise. Sits on top of whatever physics the platform supplies, rather
/// than replacing them, so an overflowing grid still feels native.
class _ScrollOnlyWhenNeeded extends ScrollPhysics {
  const _ScrollOnlyWhenNeeded({super.parent});

  @override
  _ScrollOnlyWhenNeeded applyTo(ScrollPhysics? ancestor) =>
      _ScrollOnlyWhenNeeded(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) =>
      position.maxScrollExtent > position.minScrollExtent;
}
