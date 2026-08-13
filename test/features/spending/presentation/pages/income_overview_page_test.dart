
import '../../../../helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/presentation/pages/income_overview_page.dart';
import 'package:my_pnl/features/spending/presentation/widgets/category_tile.dart';
import 'package:my_pnl/features/spending/presentation/widgets/total_circle.dart';

const _salary = CategorySpend(
  category: Category(
    id: 'income-1',
    name: 'Salary',
    colorArgb: 0xFF3B7A57,
    iconKey: 'groceries',
    kind: CategoryKind.income,
    recurring: RecurringIncome(dayOfMonth: 25, amountScaled: 350000),
  ),
  totalScaled: 700000,
);

const _groceries = CategorySpend(
  category: Category(
    id: 'category-1',
    name: 'Groceries',
    colorArgb: 0xFF4A5D8A,
    iconKey: 'groceries',
  ),
  totalScaled: 4235,
);

void main() {
  group('IncomeOverviewPage', () {
    late FakeCategoryRepository repository;

    /// Empty: with no currencies added there is nothing for the total circle to
    /// convert into, which is the state these tests read totals in.
    late FakeCurrencyRepository currencies;

    setUp(() {
      repository = FakeCategoryRepository(initial: const [_salary, _groceries]);
      currencies = FakeCurrencyRepository();
    });

    tearDown(() async {
      await currencies.close();
      await repository.close();
    });

    Future<void> pumpPage(WidgetTester tester) async {
      await tester.pumpApp(
        const IncomeOverviewPage(),
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

    testWidgets('lists income and leaves spending on the other page', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(find.text('Salary'), findsOneWidget);
      expect(find.text('Groceries'), findsNothing);
      expect(find.byType(CategoryTile), findsOneWidget);
    });

    testWidgets('totals the income rather than the spending', (tester) async {
      await pumpPage(tester);

      expect(find.text('Total income'), findsOneWidget);
      // Scoped to the circle: the single tile shows the same figure.
      expect(
        find.descendant(
          of: find.byType(TotalCircle),
          matching: find.text(r'$7,000.00'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('adds a plain income category', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      expect(find.text('New income'), findsOneWidget);

      await tester.enterText(find.widgetWithText(AppInput, 'Name'), 'Rent');
      await tester.pump();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      // Lands on this page, which only shows income.
      expect(find.text('Rent'), findsOneWidget);
      expect(find.byType(CategoryTile), findsNWidgets(2));
    });

    testWidgets('the recurring schedule stays hidden until ticked', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Recurring'), findsOneWidget);
      expect(find.widgetWithText(AppInput, 'Day'), findsNothing);

      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppInput, 'Day'), findsOneWidget);
      expect(find.widgetWithText(AppInput, 'Amount'), findsOneWidget);
    });

    testWidgets('a ticked schedule has to be filled in', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(AppInput, 'Name'),
        'Freelance',
      );
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();

      final create = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Create'),
      );
      expect(create.onPressed, isNull, reason: 'day and amount are missing');
    });

    testWidgets('saves the schedule and reopens with it', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(AppInput, 'Name'),
        'Freelance',
      );
      await tester.tap(find.text('Recurring'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(AppInput, 'Day'), '15');
      await tester.enterText(
        find.widgetWithText(AppInput, 'Amount'),
        '1200',
      );
      await tester.pump();
      await tester.ensureVisible(find.text('Create'));
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      await openSettings(tester, 'Freelance');

      expect(find.text('Edit income'), findsOneWidget);
      expect(find.widgetWithText(TextField, '15'), findsOneWidget);
      expect(find.widgetWithText(TextField, '1200.00'), findsOneWidget);
    });

    testWidgets('an existing schedule is seeded into the form', (tester) async {
      await pumpPage(tester);

      await openSettings(tester, 'Salary');

      expect(find.widgetWithText(TextField, '25'), findsOneWidget);
      expect(find.widgetWithText(TextField, '3500.00'), findsOneWidget);
    });
  });
}
