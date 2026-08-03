import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/presentation/pages/spending_overview_page.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_tile.dart';
import 'package:my_pnl/features/spending/presentation/widgets/total_circle.dart';

import '../../../../helpers/helpers.dart';

const _groceries = CategorySpend(
  category: Category(
    id: 'category-1',
    name: 'Groceries',
    colorArgb: 0xFF3B7A57,
    iconKey: 'groceries',
  ),
  totalScaled: -4235,
);

const _rent = CategorySpend(
  category: Category(
    id: 'category-2',
    name: 'Rent',
    colorArgb: 0xFF4A5D8A,
    iconKey: 'home',
  ),
  totalScaled: -120000,
);

void main() {
  group('SpendingOverviewPage', () {
    late FakeCategoryRepository repository;

    /// Empty: with no currencies added there is nothing for the total circle to
    /// convert into, which is the state these tests read totals in.
    late FakeCurrencyRepository currencies;

    setUp(() {
      repository = FakeCategoryRepository(initial: const [_groceries, _rent]);
      currencies = FakeCurrencyRepository();
    });

    tearDown(() async {
      await currencies.close();
      await repository.close();
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpApp(
        const SpendingOverviewPage(),
        categoryRepository: repository,
        currencyRepository: currencies,
        transactionRepository: repository,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders every category and the combined total', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      expect(find.text(r'-$42.35'), findsOneWidget);
      // 42.35 + 1200.00, summed as integers.
      expect(find.text(r'-$1,242.35'), findsOneWidget);
    });

    testWidgets('creates a category through the modal', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('New category'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Name'),
        'Utilities',
      );
      await tester.pump();
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('New category'), findsNothing);
      expect(find.text('Utilities'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
    });

    testWidgets('tapping a category books an amount against it', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.widgetWithText(CategoryTile, 'Groceries'));
      await tester.pumpAndSettle();
      expect(find.text('Add an amount'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '7.65');
      await tester.pump();
      await tester.tap(find.text('Save amount'));
      await tester.pumpAndSettle();

      expect(find.text('Add an amount'), findsNothing);
      // 42.35 already booked, plus 7.65.
      expect(find.text(r'-$50.00'), findsOneWidget);
      expect(find.text(r'-$1,250.00'), findsOneWidget, reason: 'new total');
    });

    testWidgets('the history icon lists what has been booked', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.widgetWithText(CategoryTile, 'Groceries'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '7.65');
      await tester.pump();
      await tester.tap(find.text('Save amount'));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Groceries history'));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      // Once as the entry, once in the sheet's running total.
      expect(find.widgetWithText(ListTile, r'-$7.65'), findsOneWidget);
      expect(find.text(r'-$7.65'), findsNWidgets(2));
    });

    testWidgets('history is empty for a category with no entries', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Rent history'));
      await tester.pumpAndSettle();

      expect(find.text('Nothing booked here yet'), findsOneWidget);
    });

    testWidgets('tapping outside the name field dismisses the keyboard', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      final field = find.descendant(
        of: find.widgetWithText(TextField, 'Name'),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(field).focusNode.hasFocus,
        isFalse,
        reason: 'the sheet opens without grabbing focus',
      );

      await tester.tap(field);
      await tester.pumpAndSettle();
      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isTrue);

      // The Color heading is inside the sheet but not a control.
      await tester.tap(find.text('Color'));
      await tester.pumpAndSettle();

      expect(tester.widget<EditableText>(field).focusNode.hasFocus, isFalse);
    });

    testWidgets('tapping a swatch still selects it', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // The unfocus handler must not swallow taps meant for the swatches.
      final swatch = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == false,
      );
      await tester.tap(swatch.first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check), findsOneWidget);
    });

    testWidgets('the new-category form offers nothing to delete', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Delete category'), findsNothing);
    });

    testWidgets('deleting a category removes it from the grid', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.longPress(find.widgetWithText(CategoryTile, 'Groceries'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      expect(find.text('Delete Groceries?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Keep entries'));
      await tester.pumpAndSettle();

      expect(
        repository.lastDeletion,
        CategoryDeletion.keepTransactions,
      );

      expect(find.text('Groceries'), findsNothing);
      expect(find.byType(CategoryTile), findsOneWidget, reason: 'Rent left');
      // Its 42.35 leaves the total, which was 1242.35. Scoped to the circle,
      // since the remaining Rent tile now shows the same figure.
      expect(
        find.descendant(
          of: find.byType(TotalCircle),
          matching: find.text(r'-$1,200.00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('deleting the entries takes the money out too', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.longPress(find.widgetWithText(CategoryTile, 'Groceries'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Delete entries'));
      await tester.pumpAndSettle();

      expect(repository.lastDeletion, CategoryDeletion.deleteTransactions);
      expect(repository.keptOnDelete, 0, reason: 'nothing left behind');
      expect(find.text('Groceries'), findsNothing);
    });

    testWidgets('cancelling keeps the category', (tester) async {
      await pumpPage(tester);

      await tester.longPress(find.widgetWithText(CategoryTile, 'Groceries'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.lastDeletion, isNull, reason: 'nothing was deleted');

      // Dialog gone, sheet still open, category untouched.
      expect(find.text('Delete Groceries?'), findsNothing);
      expect(find.text('Edit category'), findsOneWidget);
    });

    testWidgets('long-pressing a category opens it for editing', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.longPress(
        find.widgetWithText(CategoryTile, 'Groceries'),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit category'), findsOneWidget);
      // Seeded with the current values.
      expect(find.widgetWithText(TextField, 'Groceries'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Food');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit category'), findsNothing);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      // Editing must not create a second category.
      expect(find.byType(CategoryTile), findsNWidgets(2));
    });

    group('month switching', () {
      /// How the header names a month. Read from the month rather than written
      /// out, so the test says the same thing in any locale and any December.
      String labelFor(CalendarMonth month) =>
          DateFormat.yMMMM().format(month.startsOn);

      testWidgets('opens on the month happening now', (tester) async {
        await pumpPage(tester);

        expect(find.text(labelFor(CalendarMonth.now())), findsOneWidget);
      });

      testWidgets('pages back a month and forward again', (tester) async {
        await pumpPage(tester);

        final now = CalendarMonth.now();

        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();

        expect(find.text(labelFor(now.previous)), findsOneWidget);
        expect(find.text(labelFor(now)), findsNothing);

        await tester.tap(find.byTooltip('Next month'));
        await tester.pumpAndSettle();

        expect(find.text(labelFor(now)), findsOneWidget);
      });

      testWidgets('will not page past the month happening now', (tester) async {
        await pumpPage(tester);

        final forward = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right),
        );

        // Nothing can be booked in a month that has not happened, so there is
        // nowhere forward to go.
        expect(forward.onPressed, isNull);
      });

      testWidgets('fits the arrows beside the circle on a narrow phone', (
        tester,
      ) async {
        // The circle is sized from the width it is given, and the arrows are
        // not — on a phone-width screen the three still have to share a row
        // without overflowing it.
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await pumpPage(tester);

        expect(find.byType(TotalCircle), findsOneWidget);
        expect(find.byTooltip('Previous month'), findsOneWidget);
      });

      testWidgets('asks for the month it moves to', (tester) async {
        await pumpPage(tester);
        repository.requestedMonths.clear();

        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();

        expect(repository.requestedMonths, [CalendarMonth.now().previous]);
      });
    });
  });
}
