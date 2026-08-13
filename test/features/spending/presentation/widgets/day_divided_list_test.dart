import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/features/spending/presentation/widgets/day_divided_list.dart';

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  group('divideByDay', () {
    test('gives nothing back for nothing', () {
      expect(divideByDay<DateTime>(const [], (at) => at), isEmpty);
    });

    test('opens a day with a heading and hangs its entries off it', () {
      final rows = divideByDay(
        [
          DateTime(2026, 3, 14, 18),
          DateTime(2026, 3, 14, 9, 30),
          DateTime(2026, 3, 13, 20),
        ],
        (at) => at,
      );

      expect(rows, hasLength(5));
      expect(rows[0], isA<DayHeadingRow<DateTime>>());
      expect((rows[0] as DayHeadingRow<DateTime>).day, DateTime(2026, 3, 14));
      expect((rows[1] as DayEntryRow<DateTime>).opensDay, isTrue);
      expect((rows[2] as DayEntryRow<DateTime>).opensDay, isFalse);
      expect((rows[3] as DayHeadingRow<DateTime>).day, DateTime(2026, 3, 13));
      expect((rows[4] as DayEntryRow<DateTime>).opensDay, isTrue);
    });

    test('keeps the order it was handed', () {
      final entries = [
        DateTime(2026, 3, 14, 18),
        DateTime(2026, 3, 13, 20),
        DateTime(2026, 3, 12, 8),
      ];

      final kept = divideByDay(
        entries,
        (at) => at,
      ).whereType<DayEntryRow<DateTime>>().map((row) => row.entry);

      expect(kept, entries);
    });

    test('reads a stored UTC instant as the day it fell on locally', () {
      // Whichever zone the test runs in, the entry belongs under the day its
      // local clock names — never under the UTC one when they differ.
      final at = DateTime(2026, 3, 14, 23, 30).toUtc();
      final rows = divideByDay([at], (entry) => entry);

      expect((rows[0] as DayHeadingRow<DateTime>).day, DateTime(2026, 3, 14));
    });
  });

  group('formatDay', () {
    test('names the two days most entries land on', () {
      expect(formatDay(today), 'Today');
      expect(
        formatDay(DateTime(now.year, now.month, now.day - 1)),
        'Yesterday',
      );
    });

    test('drops the year on an older day within this one', () {
      // Far enough from today to be neither of the named days, whenever the
      // test runs.
      final earlier = today.month > 6
          ? DateTime(now.year, 1, 15)
          : DateTime(now.year, 12, 15);

      expect(formatDay(earlier), DateFormat.MMMEd().format(earlier));
    });

    test('keeps the year once there is a second one', () {
      // No year is 400 days long, so this always lands in an earlier one.
      final older = DateTime(now.year, now.month, now.day - 400);

      expect(formatDay(older), DateFormat.yMMMd().format(older));
    });
  });
}
