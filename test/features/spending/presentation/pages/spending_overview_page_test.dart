
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_baseline.dart';
import 'package:my_pnl/features/spending/presentation/pages/spending_overview_page.dart';
import 'package:my_pnl/features/spending/presentation/theme/overrun_style.dart';
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

/// The amount modal's first field. It carries no label — the sheet's own
/// heading says what is being typed — so it is found by position, ahead of the
/// description field under it.
final Finder _amountField = find.byType(TextField).first;

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

    /// Opens a category's own modal, the one way the grid offers: the settings
    /// icon in the corner of its tile.
    Future<void> openSettings(WidgetTester tester, String category) async {
      await tester.tap(find.bySemanticsLabel('$category settings'));
      await tester.pumpAndSettle();
    }

    /// Long-presses the tile showing [category] and drops it on [onto].
    ///
    /// Driven by hand rather than with `drag`: the tile is picked up by a long
    /// press, so the gesture has to be held still long enough to be one before
    /// it starts moving.
    Future<void> dragCategory(
      WidgetTester tester,
      String category, {
      required Finder onto,
    }) async {
      final gesture = await tester.startGesture(
        tester.getCenter(find.widgetWithText(CategoryTile, category)),
      );
      await tester.pump(kLongPressTimeout + kPressTimeout);

      // Moved in two steps: the first tells the overlay a drag is under way, the
      // second is what the cell underneath sees arrive.
      final target = tester.getCenter(onto);
      await tester.pump(kPressTimeout);
      await gesture.moveTo(target);
      await tester.pump();
      await gesture.moveTo(target);
      await tester.pump();

      await gesture.up();
      await tester.pumpAndSettle();
    }

    /// The names of the tiles in the order the grid lays them out.
    List<String> gridOrder(WidgetTester tester) {
      final tiles = tester.widgetList<CategoryTile>(find.byType(CategoryTile));
      final placed =
          [
            for (final (index, tile) in tiles.indexed)
              (
                tile.spend.category.name,
                tester.getTopLeft(find.byType(CategoryTile).at(index)),
              ),
          ]..sort((a, b) {
            final byRow = a.$2.dy.compareTo(b.$2.dy);
            return byRow != 0 ? byRow : a.$2.dx.compareTo(b.$2.dx);
          });

      return [for (final tile in placed) tile.$1];
    }

    testWidgets('renders every category and the combined total', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Groceries'), findsOneWidget);
      expect(find.text('Rent'), findsOneWidget);
      // The tiles carry magnitudes; the minus is the headline's alone.
      expect(find.text(r'$42.35'), findsOneWidget);
      // 42.35 + 1200.00, summed as integers.
      expect(find.text(r'-$1,242.35'), findsOneWidget);
    });

    testWidgets('creates a category through the modal', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('New category'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(AppInput, 'Name'),
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

      await tester.enterText(_amountField, '7.65');
      await tester.pump();
      await tester.tap(find.text('Save amount'));
      await tester.pumpAndSettle();

      expect(find.text('Add an amount'), findsNothing);
      // 42.35 already booked, plus 7.65.
      expect(find.text(r'$50.00'), findsOneWidget);
      expect(find.text(r'-$1,250.00'), findsOneWidget, reason: 'new total');
    });

    testWidgets('the settings icon lists what has been booked', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.widgetWithText(CategoryTile, 'Groceries'));
      await tester.pumpAndSettle();
      await tester.enterText(_amountField, '7.65');
      await tester.pump();
      await tester.tap(find.text('Save amount'));
      await tester.pumpAndSettle();

      // Two steps in now: the tile's icon opens the category's settings, and
      // the history hangs off that.
      await tester.tap(find.bySemanticsLabel('Groceries settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Transactions'));
      await tester.pumpAndSettle();

      expect(find.text('History'), findsOneWidget);
      // Once as the entry, once in its day's heading — the only entry that day
      // — and once in the sheet's running total.
      expect(find.widgetWithText(ListTile, r'-$7.65'), findsOneWidget);
      expect(find.text(r'-$7.65'), findsNWidgets(3));
    });

    testWidgets('history is empty for a category with no entries', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.bySemanticsLabel('Rent settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Transactions'));
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
        of: find.widgetWithText(AppInput, 'Name'),
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

      await openSettings(tester, 'Groceries');

      await tester.ensureVisible(find.text('Delete category'));
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

      await openSettings(tester, 'Groceries');
      await tester.ensureVisible(find.text('Delete category'));
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

      await openSettings(tester, 'Groceries');

      await tester.ensureVisible(find.text('Delete category'));
      await tester.tap(find.text('Delete category'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      expect(repository.lastDeletion, isNull, reason: 'nothing was deleted');

      // Dialog gone, sheet still open, category untouched.
      expect(find.text('Delete Groceries?'), findsNothing);
      expect(find.text('Edit category'), findsOneWidget);
    });

    testWidgets('the settings icon opens the category for editing', (
      tester,
    ) async {
      await pumpPage(tester);

      await openSettings(tester, 'Groceries');

      expect(find.text('Edit category'), findsOneWidget);
      // Seeded with the current values.
      expect(find.widgetWithText(TextField, 'Groceries'), findsOneWidget);

      await tester.enterText(find.widgetWithText(AppInput, 'Name'), 'Food');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Edit category'), findsNothing);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      // Editing must not create a second category.
      expect(find.byType(CategoryTile), findsNWidgets(2));
    });

    group('rearranging the grid', () {
      testWidgets('a category dropped on another takes its place', (
        tester,
      ) async {
        await pumpPage(tester);
        expect(gridOrder(tester), ['Groceries', 'Rent']);

        await dragCategory(
          tester,
          'Groceries',
          onto: find.widgetWithText(CategoryTile, 'Rent'),
        );

        expect(gridOrder(tester), ['Rent', 'Groceries']);
        // Saved, not only redrawn: the arrangement has to survive the page and
        // reach the reader's other devices.
        expect(repository.savedOrders.last, ['category-2', 'category-1']);
      });

      testWidgets('dropping on the add tile sends it to the end', (
        tester,
      ) async {
        await pumpPage(tester);

        await dragCategory(
          tester,
          'Groceries',
          onto: find.byType(AddCategoryTile),
        );

        expect(gridOrder(tester), ['Rent', 'Groceries']);
      });

      testWidgets('the order survives the page being rebuilt', (tester) async {
        await pumpPage(tester);
        await dragCategory(
          tester,
          'Groceries',
          onto: find.widgetWithText(CategoryTile, 'Rent'),
        );

        // A fresh page over the same repository: what it opens with is the
        // stored order rather than anything the last one was holding.
        await pumpPage(tester);

        expect(gridOrder(tester), ['Rent', 'Groceries']);
      });

      testWidgets('a long press no longer opens the category modal', (
        tester,
      ) async {
        await pumpPage(tester);

        await tester.longPress(find.widgetWithText(CategoryTile, 'Groceries'));
        await tester.pumpAndSettle();

        // The press lifts the tile for a drag; letting go where it started
        // changes nothing and must not leave a modal behind.
        expect(find.text('Edit category'), findsNothing);
        expect(gridOrder(tester), ['Groceries', 'Rent']);
      });
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

    group('unusual months', () {
      /// The outline the tile showing [name] is drawn with.
      BorderSide borderOf(WidgetTester tester, String name) {
        final tile = find.ancestor(
          of: find.text(name),
          matching: find.byType(CategoryTile),
        );
        final material = tester.widget<Material>(
          find.descendant(of: tile, matching: find.byType(Material)).first,
        );

        return (material.shape! as RoundedRectangleBorder).side;
      }

      /// The same two categories, with a usual month on record for each.
      Future<void> seedBaselines() async {
        await repository.close();
        repository = FakeCategoryRepository(
          initial: const [_groceries, _rent],
          baselines: const {
            // Groceries usually costs 20.00 a month, and came to 42.35.
            'category-1': SpendBaseline(averageScaled: 2000, months: 4),
            // Rent usually costs 1200.00, which is what it came to.
            'category-2': SpendBaseline(averageScaled: 120000, months: 4),
          },
        );
      }

      testWidgets('outlines the category that ran past its usual month', (
        tester,
      ) async {
        await seedBaselines();
        await pumpPage(tester);

        expect(
          borderOf(tester, 'Groceries').color,
          overrunBorderColor(SpendOverrun.severe),
        );
        // A month that came in at the usual is left alone.
        expect(borderOf(tester, 'Rent'), BorderSide.none);
      });

      testWidgets('asks for the baselines of the month it moves to', (
        tester,
      ) async {
        await seedBaselines();
        await pumpPage(tester);
        repository.requestedBaselineMonths.clear();

        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();

        expect(repository.requestedBaselineMonths, [
          CalendarMonth.now().previous,
        ]);
      });

      testWidgets('outlines nothing with no usual month on record', (
        tester,
      ) async {
        await pumpPage(tester);

        expect(borderOf(tester, 'Groceries'), BorderSide.none);
        expect(borderOf(tester, 'Rent'), BorderSide.none);
      });
    });
  });
}
