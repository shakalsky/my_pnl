import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/presentation/widgets/all_transactions_sheet.dart';

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

const _salary = CategorySpend(
  category: Category(
    id: 'income-1',
    name: 'Salary',
    colorArgb: 0xFF4A5D8A,
    iconKey: 'home',
    kind: CategoryKind.income,
  ),
  totalScaled: 0,
);

void main() {
  group('AllTransactionsSheet', () {
    late FakeCategoryRepository repository;

    setUp(() {
      repository = FakeCategoryRepository(initial: const [_groceries, _salary]);
    });

    tearDown(() => repository.close());

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => AllTransactionsSheet.show(context),
              child: const Text('open'),
            ),
          ),
        ),
        transactionRepository: repository,
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('says when there is nothing recorded', (tester) async {
      await openSheet(tester);

      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('lists entries from every category', (tester) async {
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
      );
      await repository.recordSpend(
        categoryId: _salary.category.id,
        amountScaled: 350000,
      );

      await openSheet(tester);

      // Spending negative, income positive.
      expect(find.text(r'-$12.50'), findsOneWidget);
      expect(find.text(r'$3,500.00'), findsOneWidget);
      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Salary'), findsOneWidget);
    });

    testWidgets('shows income minus spending in the header', (tester) async {
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
      );
      await repository.recordSpend(
        categoryId: _salary.category.id,
        amountScaled: 350000,
      );

      await openSheet(tester);

      expect(find.text(r'$3,487.50'), findsOneWidget);
    });

    testWidgets('updates an entry through the amount modal', (tester) async {
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
      );
      await openSheet(tester);

      await tester.tap(find.text('Groceries'));
      await tester.pumpAndSettle();
      // Opens with the magnitude, not the stored negative.
      expect(find.widgetWithText(TextField, '12.50'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '9.99');
      await tester.pump();
      await tester.tap(find.text('Save amount'));
      await tester.pumpAndSettle();

      // Scoped to the row: with one entry the header net reads the same.
      expect(find.widgetWithText(ListTile, r'-$9.99'), findsOneWidget);
      expect(find.text(r'-$12.50'), findsNothing);
    });

    testWidgets('deletes an entry after confirming', (tester) async {
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
      );
      await openSheet(tester);

      await tester.tap(find.byTooltip('Delete entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing recorded yet'), findsOneWidget);
    });

    testWidgets('keeps the entry when the user cancels', (tester) async {
      await repository.recordSpend(
        categoryId: _groceries.category.id,
        amountScaled: 1250,
      );
      await openSheet(tester);

      await tester.tap(find.byTooltip('Delete entry'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(ListTile, r'-$12.50'), findsOneWidget);
    });

    group('divided by day', () {
      testWidgets('heads each day the entries fall on', (tester) async {
        final now = DateTime.now();

        await repository.recordSpend(
          categoryId: _groceries.category.id,
          amountScaled: 1250,
          // Built from the fields rather than by subtracting hours: a test that
          // runs just after midnight, or on the night the clocks change, must
          // still book one entry today and one yesterday.
          occurredAt: DateTime(now.year, now.month, now.day, 12),
        );
        await repository.recordSpend(
          categoryId: _salary.category.id,
          amountScaled: 350000,
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
          categoryId: _salary.category.id,
          amountScaled: 350000,
          occurredAt: DateTime(now.year, now.month, now.day, 9),
        );
        await openSheet(tester);

        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Yesterday'), findsNothing);
      });
    });

    group('in a family account', () {
      testWidgets("labels a partner's entry and not your own", (tester) async {
        await repository.recordSpend(
          categoryId: _groceries.category.id,
          amountScaled: 1250,
        );
        repository.recordPartnerSpend(
          categoryId: _groceries.category.id,
          amountScaled: 4000,
        );
        await openSheet(tester);

        // One name, on one row: in a list where a partner's rows are labelled,
        // the unlabelled ones being yours needs no second marker.
        expect(find.text('kate'), findsOneWidget);
      });

      testWidgets("offers no delete on a partner's entry", (tester) async {
        repository.recordPartnerSpend(
          categoryId: _groceries.category.id,
          amountScaled: 4000,
        );
        await openSheet(tester);

        // Disabled rather than absent, so the row still lines up with the ones
        // around it — and disabled rather than enabled-and-refused, because the
        // Postgres policy would drop the upload rather than report it.
        final bin = tester.widget<IconButton>(
          find.ancestor(
            of: find.byTooltip('Only kate can change this'),
            matching: find.byType(IconButton),
          ),
        );
        expect(bin.onPressed, isNull);
        expect(find.byTooltip('Delete entry'), findsNothing);
      });

      testWidgets("does not open the editor for a partner's entry", (
        tester,
      ) async {
        repository.recordPartnerSpend(
          categoryId: _groceries.category.id,
          amountScaled: 4000,
        );
        await openSheet(tester);

        final row = tester.widget<ListTile>(
          find.widgetWithText(ListTile, r'-$40.00'),
        );
        expect(row.onTap, isNull);
      });

      testWidgets('adds both partners into the figure at the top', (
        tester,
      ) async {
        await repository.recordSpend(
          categoryId: _groceries.category.id,
          amountScaled: 1250,
        );
        repository.recordPartnerSpend(
          categoryId: _groceries.category.id,
          amountScaled: 4000,
        );
        await openSheet(tester);

        // The point of the whole feature, at the one place it is written out as
        // a single number.
        expect(find.text(r'-$52.50'), findsOneWidget);
      });
    });
  });
}
