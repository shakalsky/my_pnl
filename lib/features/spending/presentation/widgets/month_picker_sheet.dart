import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/i18n/strings.g.dart';

/// Picks the month both overviews are read for.
///
/// A year to step through and its twelve months to tap, rather than a date
/// picker: the overviews are grouped by month, and a picker that asks for a day
/// would have the reader choose something the figures know nothing about.
///
/// Returns the chosen [CalendarMonth], or null if the sheet was dismissed.
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({
    required this.selected,
    required this.latest,
    super.key,
  });

  /// Which month is open now, so the sheet opens on its year with it marked.
  final CalendarMonth selected;

  /// The last month that can be chosen.
  final CalendarMonth latest;

  static Future<CalendarMonth?> show(
    BuildContext context, {
    required CalendarMonth selected,
  }) {
    return showModalBottomSheet<CalendarMonth>(
      context: context,
      showDragHandle: true,
      // Capped at the month happening now, for the same reason the forward
      // arrow stops there: nothing can be booked in a month that has not
      // happened, so an empty future month is not a month to read.
      builder: (_) => MonthPickerSheet(
        selected: selected,
        latest: CalendarMonth.now(),
      ),
    );
  }

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
  /// The year on show, which is not yet a choice: stepping through years moves
  /// this alone, and only a month tapped closes the sheet.
  late int _year = widget.selected.year;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = CalendarMonth.now();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.spending.selectMonth, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  tooltip: t.spending.previousYear,
                  onPressed: () => setState(() => _year--),
                ),
                Text(
                  '$_year',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  tooltip: t.spending.nextYear,
                  // A year with no month in it that can be chosen is a year
                  // worth nothing to step into.
                  onPressed: _year < widget.latest.year
                      ? () => setState(() => _year++)
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              // The sheet is as tall as its contents, so the grid lays out in
              // full and has nothing of its own to scroll.
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 44,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: DateTime.monthsPerYear,
              itemBuilder: (context, index) {
                final month = CalendarMonth(_year, index + 1);

                return _MonthCell(
                  // Named by the locale's own abbreviations rather than by a
                  // list written here, so a month reads the same in the grid as
                  // it does in the heading above the figures.
                  label: DateFormat.MMM().format(month.startsOn),
                  selected: month == widget.selected,
                  isCurrent: month == now,
                  onTap: month.isAfter(widget.latest)
                      ? null
                      : () => Navigator.of(context).pop(month),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One month in the grid.
class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  final String label;
  final bool selected;

  /// The month happening now, outlined so the grid says where the present is
  /// even while a year long past is on show.
  final bool isCurrent;

  /// Null for a month that cannot be chosen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final enabled = onTap != null;

    final foreground = switch ((selected, enabled)) {
      (true, _) => colors.onPrimary,
      (false, true) => colors.onSurface,
      (false, false) => colors.onSurface.withValues(alpha: 0.38),
    };

    return Material(
      color: selected ? colors.primary : colors.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isCurrent && !selected
            ? BorderSide(color: colors.primary)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w600 : null,
            ),
          ),
        ),
      ),
    );
  }
}
