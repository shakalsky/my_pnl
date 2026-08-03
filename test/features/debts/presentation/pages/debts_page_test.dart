import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/presentation/pages/debts_page.dart';

import '../../../../helpers/helpers.dart';

const _lentToAlex = Debt(
  id: 'debt-1',
  counterparty: 'Alex',
  direction: DebtDirection.owedToMe,
  amountScaled: 2500,
  note: 'Concert ticket',
);

const _oweLandlord = Debt(
  id: 'debt-2',
  counterparty: 'Landlord',
  direction: DebtDirection.owedByMe,
  amountScaled: 90000,
  note: 'August rent',
);

void main() {
  group('DebtsPage', () {
    late FakeDebtRepository repository;

    setUp(() => repository = FakeDebtRepository());
    tearDown(() => repository.close());

    Future<void> openPage(WidgetTester tester) async {
      await tester.pumpApp(const DebtsPage(), debtRepository: repository);
      await tester.pumpAndSettle();
    }

    testWidgets('says when there are no debts', (tester) async {
      await openPage(tester);

      expect(find.text('No debts yet'), findsOneWidget);
      expect(find.text('You are square'), findsOneWidget);
    });

    testWidgets('lists each side under its own heading', (tester) async {
      repository = FakeDebtRepository(
        initial: const [_lentToAlex, _oweLandlord],
      );
      await openPage(tester);

      expect(find.text('They owe you'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
      expect(find.text('Concert ticket'), findsOneWidget);

      expect(find.text('You owe'), findsOneWidget);
      expect(find.text('Landlord'), findsOneWidget);
      expect(find.text(r'$900.00'), findsWidgets);
    });

    testWidgets('totals each side and says where they leave you', (
      tester,
    ) async {
      repository = FakeDebtRepository(
        initial: const [_lentToAlex, _oweLandlord],
      );
      await openPage(tester);

      expect(find.text('Owed to you'), findsOneWidget);
      expect(find.text('Owed by you'), findsOneWidget);
      // 900.00 owed out against 25.00 owed in.
      expect(find.text(r'You owe $875.00 overall'), findsOneWidget);
    });

    testWidgets('adds a debt through the form', (tester) async {
      await openPage(tester);

      await tester.tap(find.byTooltip('Add debt'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Who'), 'Sam');
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '40');
      await tester.pump();
      await tester.tap(find.text('Add debt').last);
      await tester.pumpAndSettle();

      final saved = (await repository.watchDebts().first).single;
      expect(saved.counterparty, 'Sam');
      expect(saved.direction, DebtDirection.owedToMe);
      expect(saved.amountScaled, 4000);
      expect(find.text('Sam'), findsOneWidget);
    });

    testWidgets('records a debt the user owes', (tester) async {
      await openPage(tester);

      await tester.tap(find.byTooltip('Add debt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('I owe'));
      await tester.enterText(find.widgetWithText(TextField, 'Who'), 'Sam');
      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '40');
      await tester.pump();
      await tester.tap(find.text('Add debt').last);
      await tester.pumpAndSettle();

      final saved = (await repository.watchDebts().first).single;
      expect(saved.direction, DebtDirection.owedByMe);
      expect(find.text('You owe'), findsOneWidget);
    });

    testWidgets('editing a debt changes the amount shown', (tester) async {
      repository = FakeDebtRepository(initial: const [_lentToAlex]);
      await openPage(tester);

      await tester.tap(find.text('Alex'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Amount'), '30');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect((await repository.watchDebts().first).single.amountScaled, 3000);
      expect(find.text(r'$30.00'), findsWidgets);
    });

    testWidgets('marking a debt settled moves it out of the open list', (
      tester,
    ) async {
      repository = FakeDebtRepository(initial: const [_lentToAlex]);
      await openPage(tester);

      await tester.tap(find.byTooltip('Actions for Alex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark settled'));
      await tester.pumpAndSettle();

      expect((await repository.watchDebts().first).single.isSettled, isTrue);
      expect(find.text('Settled'), findsOneWidget);
      expect(find.text('They owe you'), findsNothing);
      // Settled debts drop out of the position: that money has been paid.
      expect(find.text('You are square'), findsOneWidget);
    });

    testWidgets('a settled debt can be reopened', (tester) async {
      repository = FakeDebtRepository(
        initial: [_lentToAlex.copyWith(settledAt: DateTime.utc(2026))],
      );
      await openPage(tester);

      await tester.tap(find.byTooltip('Actions for Alex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reopen'));
      await tester.pumpAndSettle();

      expect((await repository.watchDebts().first).single.isSettled, isFalse);
      expect(find.text('They owe you'), findsOneWidget);
    });

    testWidgets('deletes a debt after confirming', (tester) async {
      repository = FakeDebtRepository(initial: const [_lentToAlex]);
      await openPage(tester);

      await tester.tap(find.byTooltip('Actions for Alex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(await repository.watchDebts().first, isEmpty);
      expect(find.text('No debts yet'), findsOneWidget);
    });

    testWidgets('keeps the debt when the user cancels', (tester) async {
      repository = FakeDebtRepository(initial: const [_lentToAlex]);
      await openPage(tester);

      await tester.tap(find.byTooltip('Actions for Alex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(await repository.watchDebts().first, hasLength(1));
      expect(find.text('Alex'), findsOneWidget);
    });

    testWidgets('reports a failed settle without losing the row', (
      tester,
    ) async {
      repository = FakeDebtRepository(initial: const [_lentToAlex])
        ..writeError = Exception('offline');
      await openPage(tester);

      await tester.tap(find.byTooltip('Actions for Alex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark settled'));
      await tester.pumpAndSettle();

      expect(find.text('Could not update that debt'), findsOneWidget);
      expect(find.text('Alex'), findsOneWidget);
    });
  });
}
