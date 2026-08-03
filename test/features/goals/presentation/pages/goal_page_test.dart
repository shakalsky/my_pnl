import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/presentation/pages/goal_page.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';

import '../../../../helpers/helpers.dart';

const _salary = CategorySpend(
  category: Category(
    id: 'income-1',
    name: 'Salary',
    colorArgb: 1,
    iconKey: 'wallet',
    kind: CategoryKind.income,
  ),
  totalScaled: 0,
);

const _rent = CategorySpend(
  category: Category(id: 'expense-1', name: 'Rent', colorArgb: 2, iconKey: 'x'),
  totalScaled: 0,
);

void main() {
  group('GoalPage', () {
    late FakeCategoryRepository spending;
    late FakeGoalRepository goals;

    setUp(() {
      spending = FakeCategoryRepository(initial: const [_salary, _rent]);
      goals = FakeGoalRepository();
    });

    tearDown(() async {
      await goals.close();
      await spending.close();
    });

    /// Books [amountScaled] in the given month. The fake signs it from the
    /// category, so income lands positive and spending negative.
    Future<void> book({
      required String categoryId,
      required int amountScaled,
      required DateTime on,
    }) => spending.recordSpend(
      categoryId: categoryId,
      amountScaled: amountScaled,
      occurredAt: on,
    );

    /// March up 2000, April down 400.
    Future<void> bookAMixOfMonths() async {
      await book(
        categoryId: _salary.category.id,
        amountScaled: 300000,
        on: DateTime.utc(2026, 3, 5),
      );
      await book(
        categoryId: _rent.category.id,
        amountScaled: 100000,
        on: DateTime.utc(2026, 3, 28),
      );
      await book(
        categoryId: _rent.category.id,
        amountScaled: 40000,
        on: DateTime.utc(2026, 4, 2),
      );
    }

    Future<void> openPage(WidgetTester tester) async {
      await tester.pumpApp(
        const GoalPage(),
        goalRepository: goals,
        transactionRepository: spending,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('offers to set a goal when there is none', (tester) async {
      await openPage(tester);

      expect(find.text('Set a goal'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byTooltip('Remove goal'), findsNothing);
    });

    testWidgets('lists each month that finished up', (tester) async {
      await bookAMixOfMonths();
      await openPage(tester);

      expect(find.text('March 2026'), findsOneWidget);
      expect(find.text(r'+$2,000.00'), findsOneWidget);
      // April ended down, so it is not in the list...
      expect(find.text('April 2026'), findsNothing);
      // ...but it is not hidden either.
      expect(
        find.textContaining(r'1 month ended down, $400.00'),
        findsOneWidget,
      );
    });

    testWidgets('adds up the positive months as the saved figure', (
      tester,
    ) async {
      await book(
        categoryId: _salary.category.id,
        amountScaled: 300000,
        on: DateTime.utc(2026, 3, 5),
      );
      await book(
        categoryId: _salary.category.id,
        amountScaled: 100000,
        on: DateTime.utc(2026, 5, 5),
      );
      await openPage(tester);

      expect(find.text(r'$4,000.00'), findsOneWidget);
      expect(find.text('May 2026'), findsOneWidget);
      expect(find.text('March 2026'), findsOneWidget);
    });

    testWidgets('says when no month has finished up', (tester) async {
      await book(
        categoryId: _rent.category.id,
        amountScaled: 40000,
        on: DateTime.utc(2026, 4, 2),
      );
      await openPage(tester);

      expect(find.textContaining('No month has finished up yet'), findsOneWidget);
      expect(find.text(r'$0.00'), findsOneWidget);
    });

    testWidgets('sets a goal through the form and shows the progress', (
      tester,
    ) async {
      await bookAMixOfMonths();
      await openPage(tester);

      await tester.tap(find.text('Set a goal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Target'), '5000');
      await tester.pump();
      await tester.tap(find.text('Set goal'));
      await tester.pumpAndSettle();

      expect((await goals.watchGoal().first)?.targetAmountScaled, 500000);
      // 2000 of 5000.
      expect(find.text(r'of $5,000.00'), findsOneWidget);
      expect(find.text('40%'), findsOneWidget);
      expect(find.text(r'$3,000.00 to go'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('draws the bar at the fraction saved', (tester) async {
      goals = FakeGoalRepository(
        initial: const SavingsGoal(id: 'goal-1', targetAmountScaled: 500000),
      );
      await bookAMixOfMonths();
      await openPage(tester);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.4, 0.001));
    });

    testWidgets('says so once the goal is reached', (tester) async {
      goals = FakeGoalRepository(
        initial: const SavingsGoal(id: 'goal-1', targetAmountScaled: 100000),
      );
      await bookAMixOfMonths();
      await openPage(tester);

      expect(find.text('Goal reached'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);

      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, 1, reason: 'capped rather than overflowing');
    });

    testWidgets('edits the target', (tester) async {
      goals = FakeGoalRepository(
        initial: const SavingsGoal(id: 'goal-1', targetAmountScaled: 500000),
      );
      await bookAMixOfMonths();
      await openPage(tester);

      await tester.tap(find.text('Edit goal'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '5000.00',
        reason: 'opens with the current figure',
      );

      await tester.enterText(find.widgetWithText(TextField, 'Target'), '4000');
      await tester.pump();
      await tester.tap(find.text('Save goal'));
      await tester.pumpAndSettle();

      expect((await goals.watchGoal().first)?.targetAmountScaled, 400000);
      expect(find.text(r'of $4,000.00'), findsOneWidget);
    });

    testWidgets('removes the goal after confirming', (tester) async {
      goals = FakeGoalRepository(
        initial: const SavingsGoal(id: 'goal-1', targetAmountScaled: 500000),
      );
      await bookAMixOfMonths();
      await openPage(tester);

      await tester.tap(find.byTooltip('Remove goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(await goals.watchGoal().first, isNull);
      expect(find.text('Set a goal'), findsOneWidget);
      // The months are untouched by losing the target.
      expect(find.text('March 2026'), findsOneWidget);
    });

    testWidgets('keeps the goal when the user cancels', (tester) async {
      goals = FakeGoalRepository(
        initial: const SavingsGoal(id: 'goal-1', targetAmountScaled: 500000),
      );
      await openPage(tester);

      await tester.tap(find.byTooltip('Remove goal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await goals.watchGoal().first, isNotNull);
    });

    testWidgets('reports a goal that could not be saved', (tester) async {
      goals = FakeGoalRepository()..writeError = Exception('offline');
      await openPage(tester);

      await tester.tap(find.text('Set a goal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Target'), '5000');
      await tester.pump();
      await tester.tap(find.text('Set goal'));
      await tester.pumpAndSettle();

      expect(find.text('Could not save your goal'), findsOneWidget);
      expect(
        find.text('Set goal'),
        findsOneWidget,
        reason: 'the sheet stays open to be corrected',
      );
    });
  });
}
