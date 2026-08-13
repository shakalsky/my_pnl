import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpApp(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  TransactionHistorySheet.show(context, _groceries.category),
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
  });
}
