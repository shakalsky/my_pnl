import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_history.dart';
import 'package:my_pnl/features/spending/presentation/bloc/transaction_history/transaction_history_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _groceries = Category(
  id: 'category-1',
  name: 'Groceries',
  colorArgb: 0xFF3B7A57,
  iconKey: 'groceries',
);

void main() {
  group('TransactionHistoryBloc', () {
    late FakeCategoryRepository repository;

    setUp(() {
      repository = FakeCategoryRepository(
        initial: const [CategorySpend(category: _groceries, totalScaled: 0)],
      );
    });

    tearDown(() => repository.close());

    TransactionHistoryBloc build() => TransactionHistoryBloc(
      watchCategoryHistory: WatchCategoryHistory(repository),
      deleteSpend: DeleteSpend(repository),
      category: _groceries,
    );

    blocTest<TransactionHistoryBloc, TransactionHistoryState>(
      'starts empty for a category with no entries',
      build: build,
      act: (bloc) => bloc.add(const TransactionHistorySubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.status, TransactionHistoryStatus.success);
        expect(bloc.state.entries, isEmpty);
        expect(bloc.state.totalScaled, 0);
      },
    );

    blocTest<TransactionHistoryBloc, TransactionHistoryState>(
      'picks up entries as they are recorded',
      build: build,
      act: (bloc) async {
        bloc.add(const TransactionHistorySubscriptionRequested());
        await pumpEventQueue();
        await repository.recordSpend(
          categoryId: _groceries.id,
          amountScaled: 1250,
        );
        await repository.recordSpend(
          categoryId: _groceries.id,
          amountScaled: 500,
        );
      },
      verify: (bloc) {
        expect(bloc.state.entries, hasLength(2));
        expect(bloc.state.totalScaled, -1750);
        expect(bloc.state.entries.first.occurredAt.isUtc, isTrue);
      },
    );

    blocTest<TransactionHistoryBloc, TransactionHistoryState>(
      'drops a deleted entry and its amount',
      build: build,
      act: (bloc) async {
        bloc.add(const TransactionHistorySubscriptionRequested());
        await pumpEventQueue();
        await repository.recordSpend(
          categoryId: _groceries.id,
          amountScaled: 1250,
        );
        await repository.recordSpend(
          categoryId: _groceries.id,
          amountScaled: 500,
        );
        await pumpEventQueue();

        bloc.add(TransactionHistoryEntryDeleted(bloc.state.entries.first.id));
      },
      verify: (bloc) {
        expect(bloc.state.entries, hasLength(1));
        expect(bloc.state.totalScaled, -1250);
        expect(bloc.state.errorMessage, isNull);
      },
    );

    blocTest<TransactionHistoryBloc, TransactionHistoryState>(
      'reports a failed delete without emptying the list',
      build: build,
      act: (bloc) async {
        bloc.add(const TransactionHistorySubscriptionRequested());
        await pumpEventQueue();
        await repository.recordSpend(
          categoryId: _groceries.id,
          amountScaled: 1250,
        );
        await pumpEventQueue();

        repository.writeError = Exception('offline');
        bloc.add(TransactionHistoryEntryDeleted(bloc.state.entries.first.id));
      },
      verify: (bloc) {
        expect(bloc.state.errorMessage, 'Could not delete that entry');
        expect(bloc.state.status, TransactionHistoryStatus.success);
        expect(bloc.state.entries, hasLength(1));
      },
    );
  });
}
