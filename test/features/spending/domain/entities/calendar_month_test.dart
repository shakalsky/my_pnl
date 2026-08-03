import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';

void main() {
  group('CalendarMonth', () {
    test('reads the month a moment falls in, in UTC', () {
      // Half an hour into April, UTC — which is still March in a timezone an
      // hour behind, and the ledger groups by UTC.
      expect(
        CalendarMonth.of(DateTime.utc(2026, 4, 1, 0, 30)),
        const CalendarMonth(2026, 4),
      );
    });

    test('converts a local time before reading it', () {
      final local = DateTime(2026, 3, 14, 9, 30);

      expect(CalendarMonth.of(local), CalendarMonth.of(local.toUtc()));
    });

    test('steps forward through the year', () {
      expect(const CalendarMonth(2026, 3).next, const CalendarMonth(2026, 4));
    });

    test('rolls the year over at December', () {
      expect(const CalendarMonth(2026, 12).next, const CalendarMonth(2027, 1));
    });

    test('steps back through the year', () {
      expect(
        const CalendarMonth(2026, 3).previous,
        const CalendarMonth(2026, 2),
      );
    });

    test('rolls the year back at January', () {
      expect(
        const CalendarMonth(2026, 1).previous,
        const CalendarMonth(2025, 12),
      );
    });

    test('orders across a year boundary', () {
      const december = CalendarMonth(2025, 12);
      const january = CalendarMonth(2026, 1);

      expect(december.isBefore(january), isTrue);
      expect(january.isAfter(december), isTrue);
      // Neither, being the same month.
      expect(january.isBefore(january), isFalse);
      expect(january.isAfter(january), isFalse);
    });

    test('is the same month whatever moment in it it was read from', () {
      expect(
        CalendarMonth.of(DateTime.utc(2026, 3)),
        CalendarMonth.of(DateTime.utc(2026, 3, 31, 23, 59)),
      );
    });

    test('names the first instant of the month for formatting', () {
      expect(const CalendarMonth(2026, 3).startsOn, DateTime(2026, 3));
    });
  });
}
