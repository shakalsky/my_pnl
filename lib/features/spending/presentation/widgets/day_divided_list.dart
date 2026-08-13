import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A row in a list broken up by day: either a day's heading or one entry under
/// it.
///
/// Both transaction lists are flat runs of entries ordered by time, which reads
/// as one undifferentiated column once there are more than a screenful. Turning
/// them into rows of this type is what lets a single [ListView] lay out the
/// headings and the entries together, still building lazily.
sealed class DayRow<T> {
  const DayRow();
}

final class DayHeadingRow<T> extends DayRow<T> {
  const DayHeadingRow(this.day);

  /// Local midnight of the day the entries under it fall on.
  final DateTime day;
}

final class DayEntryRow<T> extends DayRow<T> {
  const DayEntryRow(this.entry, {required this.opensDay});

  final T entry;

  /// Whether this is the first entry under its heading — the one row that wants
  /// no divider above it, because the heading already separates it.
  final bool opensDay;
}

/// Walks an already-ordered list and inserts a heading wherever the day changes.
///
/// The order is left exactly as it came: the queries behind both lists sort by
/// time, so entries sharing a day already sit next to each other and a run ends
/// where the day does. Days are compared in the reader's zone rather than in the
/// UTC the entries are stored in, so a late-evening entry stays on the day the
/// person who booked it would name.
List<DayRow<T>> divideByDay<T>(
  List<T> entries,
  DateTime Function(T entry) occurredAt,
) {
  final rows = <DayRow<T>>[];
  DateTime? currentDay;

  for (final entry in entries) {
    final local = occurredAt(entry).toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final opensDay = day != currentDay;

    if (opensDay) {
      rows.add(DayHeadingRow<T>(day));
      currentDay = day;
    }

    rows.add(DayEntryRow<T>(entry, opensDay: opensDay));
  }

  return rows;
}

/// The heading that opens one day's entries.
///
/// A band rather than a bare line of text: the hairline between two rows already
/// means "next entry", so a day boundary has to say something louder than that
/// or it reads as one more row. Full width, so the eye can follow it across and
/// see where one day's spending stops.
class DayHeading extends StatelessWidget {
  const DayHeading({required this.day, this.first = false, super.key});

  /// Local midnight, as [divideByDay] hands it over.
  final DateTime day;

  /// Whether this opens the list rather than breaking it.
  ///
  /// The first day needs no gap above it — there is nothing up there to be
  /// separated from, and the space would only push the list off the sheet.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 20, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!first)
            Divider(
              height: 1,
              thickness: 1,
              color: theme.colorScheme.outlineVariant,
            ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: Text(
                formatDay(day),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What a day heading reads.
///
/// The two days most entries land on are named rather than dated, because that
/// is how the person who booked them thinks of them. Older days within this year
/// drop the year, which is only noise until there is a second one.
String formatDay(DateTime day) {
  final now = DateTime.now();
  // Built from the fields rather than by subtracting a day: on the night the
  // clocks change, a day is not 24 hours, and yesterday would come out as today.
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);

  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';

  return day.year == today.year
      ? DateFormat.MMMEd().format(day)
      : DateFormat.yMMMd().format(day);
}
