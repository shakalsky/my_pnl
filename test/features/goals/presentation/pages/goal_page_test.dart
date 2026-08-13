
import '../../../../helpers/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/core/widgets/text_input/app_input.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/presentation/pages/goal_page.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';

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
      // ...but it is not hidden either, further down the page.
      final note = find.textContaining(r'1 month ended down, $400.00');
      await tester.scrollUntilVisible(note, 200);
      expect(note, findsOneWidget);
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
      // Further down the page, under the projection card.
      final march = find.text('March 2026');
      await tester.scrollUntilVisible(march, 200);
      expect(march, findsOneWidget);
    });

    testWidgets('says when no month has finished up', (tester) async {
      await book(
        categoryId: _rent.category.id,
        amountScaled: 40000,
        on: DateTime.utc(2026, 4, 2),
      );
      await openPage(tester);

      expect(
        find.textContaining('No month has finished up yet'),
        findsOneWidget,
      );
      expect(find.text(r'$0.00'), findsOneWidget);
    });

    testWidgets('sets a goal through the form and shows the progress', (
      tester,
    ) async {
      await bookAMixOfMonths();
      await openPage(tester);

      await tester.tap(find.text('Set a goal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(AppInput, 'Target'), '5000');
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

    testWidgets('will not take a target past a trillion', (tester) async {
      await bookAMixOfMonths();
      await openPage(tester);

      await tester.tap(find.text('Set a goal'));
      await tester.pumpAndSettle();

      final field = find.widgetWithText(AppInput, 'Target');
      await tester.enterText(field, '1000000000000');
      await tester.pump();
      // The last digit is refused rather than the whole figure, so what was
      // already typed stays put.
      await tester.enterText(field, '10000000000000');
      await tester.pump();

      expect(tester.widget<AppInput>(field).controller?.text, '1000000000000');

      await tester.tap(find.text('Set goal'));
      await tester.pumpAndSettle();

      expect(
        (await goals.watchGoal().first)?.targetAmountScaled,
        100000000000000,
      );
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

      await tester.enterText(find.widgetWithText(AppInput, 'Target'), '4000');
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

    testWidgets('projects what the saved total would earn invested', (
      tester,
    ) async {
      await bookAMixOfMonths();
      await openPage(tester);

      // 2000 saved at the opening 5% over 10 years grows to 3,257.79, and a day
      // at that point earns 44 cents — not the 27 it earns today.
      expect(find.text('If invested'), findsOneWidget);
      expect(find.text(r'$0.44'), findsOneWidget);
      expect(find.text('5% a year'), findsOneWidget);
      expect(
        find.text(r'10 years on, with $3,257.79 in the pot'),
        findsOneWidget,
      );
    });

    testWidgets('reprojects as the rate slider moves', (tester) async {
      await bookAMixOfMonths();
      await openPage(tester);

      // Dragging to the far end of the track picks up the maximum rate.
      await tester.drag(find.byType(Slider).first, const Offset(500, 0));
      await tester.pumpAndSettle();

      expect(find.text('20% a year'), findsOneWidget);
      // 2000 at 20% grows to 12,383.47 over ten years, and a day of that earns
      // 6.19 where today it earns a dollar.
      expect(find.text(r'$6.19'), findsOneWidget);
      expect(
        find.text(r'10 years on, with $12,383.47 in the pot'),
        findsOneWidget,
      );
      // The saved figure itself is unchanged by the what-if.
      expect(find.text(r'$2,000.00'), findsOneWidget);
    });

    testWidgets('reprojects as the years slider moves', (tester) async {
      await bookAMixOfMonths();
      await openPage(tester);

      // Back to the near end of the years track: one year.
      await tester.drag(find.byType(Slider).last, const Offset(-500, 0));
      await tester.pumpAndSettle();

      // One year at 5% adds the plain percentage of 2000...
      expect(
        find.text(r'1 year on, with $2,100.00 in the pot'),
        findsOneWidget,
      );
      // ...and a day at the end of that one year earns 28 cents, well short of
      // the 44 a day ten years in.
      expect(find.text(r'$0.28'), findsOneWidget);
    });

    testWidgets('the sliders stay inside 3 to 20 percent and 1 to 50 years', (
      tester,
    ) async {
      await bookAMixOfMonths();
      await openPage(tester);

      final rate = tester.widget<Slider>(find.byType(Slider).first);
      expect(rate.min, 3);
      expect(rate.max, 20);
      expect(rate.value, 5);

      final years = tester.widget<Slider>(find.byType(Slider).last);
      expect(years.min, 1);
      expect(years.max, 50);
      expect(years.value, 10);
    });

    testWidgets('reports a goal that could not be saved', (tester) async {
      goals = FakeGoalRepository()..writeError = Exception('offline');
      await openPage(tester);

      await tester.tap(find.text('Set a goal'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(AppInput, 'Target'), '5000');
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
