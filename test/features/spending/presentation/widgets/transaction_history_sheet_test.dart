import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/presentation/widgets/transaction_history_sheet.dart';

import '../../../../helpers/helpers.dart';

const _groceries = CategorySpend(
  category: Category(
    id: 'category-1',
    name: 'Groceries',
    colorArgb: 0xFF3B7A57,
    iconKey: 'groceries',
  ),
  totalScaled: 0,
);

void main() {
  group('TransactionHistorySheet', () {
    late FakeCategoryRepository repository;

    setUp(() {
      repository = FakeCategoryRepository(initial: const [_groceries]);
    });

    tearDown(() => repository.close());

    /// Opens the sheet over [month] — or, with none, over the whole history,
    /// which is what the day-heading tests below read their entries in.
    Future<void> openSheet(WidgetTester tester, {CalendarMonth? month}) async {
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => TransactionHistorySheet.show(
                context,
                _groceries.category,
                month: month,
              ),
              child: const Text('open'),
            ),
          ),
        ),
        transactionRepository: repository,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('heads each day the entries fall on', (tester) async {
      final now = DateTime.now();

      // Built from the fields rather than by subtracting hours: a test that
      // runs just after midnight, or on the night the clocks change, must still
      // book one entry today and one yesterday.
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
        occurredAt: DateTime(now.year, now.month, now.day, 12),
      );
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 4000,
        occurredAt: DateTime(now.year, now.month, now.day - 1, 12),
      );
      await openSheet(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('heads a day once however many entries it holds', (
      tester,
    ) async {
      final now = DateTime.now();

      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
        occurredAt: DateTime(now.year, now.month, now.day, 12),
      );
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 4000,
        occurredAt: DateTime(now.year, now.month, now.day, 9),
      );
      await openSheet(tester);

      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsNothing);
    });

    group('scoped to one month', () {
      /// 12.50 on 14 March, 40.00 on 2 April.
      Future<void> seedTwoMonths() async {
        await repository.recordSpend(
          categoryId: _groceries.category.id,
          amountScaled: 1250,
          occurredAt: DateTime.utc(2026, 3, 14, 9, 30),
        );
        await repository.recordSpend(
          categoryId: _groceries.category.id,
          amountScaled: 4000,
          occurredAt: DateTime.utc(2026, 4, 2, 9, 30),
        );
      }

      testWidgets('lists what was booked in that month and nothing else', (
        tester,
      ) async {
        await seedTwoMonths();
        await openSheet(tester, month: const CalendarMonth(2026, 3));

        // What the tile behind it shows for March, and only that: a history
        // running back over every month would not add up to the figure tapped.
        expect(find.text(r'-$12.50'), findsWidgets);
        expect(find.text(r'-$40.00'), findsNothing);
      });

      testWidgets('names the month under the category', (tester) async {
        await seedTwoMonths();
        await openSheet(tester, month: const CalendarMonth(2026, 3));

        final march = DateFormat.yMMMM().format(DateTime(2026, 3));
        expect(find.text('$march · History'), findsOneWidget);
      });

      testWidgets('a month with nothing in it says so', (tester) async {
        await seedTwoMonths();
        await openSheet(tester, month: const CalendarMonth(2026, 2));

        expect(find.text('Nothing booked here yet'), findsOneWidget);
      });

      testWidgets('lists every month with none asked for', (tester) async {
        await seedTwoMonths();
        await openSheet(tester);

        expect(find.text(r'-$12.50'), findsWidgets);
        expect(find.text(r'-$40.00'), findsWidgets);
      });
    });
  });
}
