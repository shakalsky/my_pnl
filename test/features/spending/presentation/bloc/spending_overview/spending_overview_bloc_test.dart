import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/category_spend.dart';
import 'package:my_pnl/features/spending/domain/repositories/category_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_net_total.dart';
import 'package:my_pnl/features/spending/presentation/bloc/spending_overview/spending_overview_bloc.dart';

import '../../../../../helpers/helpers.dart';

const _groceries = CategorySpend(
  category: Category(
    id: 'a',
    name: 'Groceries',
    colorArgb: 1,
    iconKey: 'groceries',
  ),
  totalScaled: 4235,
);

const _rent = CategorySpend(
  category: Category(id: 'b', name: 'Rent', colorArgb: 2, iconKey: 'home'),
  totalScaled: 120000,
);

class _FailingRepository implements CategoryRepository {
  @override
  Stream<List<CategorySpend>> watchCategorySpend(
    CategoryKind kind, {
    CalendarMonth? month,
  }) => Stream.error(Exception('nope'));

  @override
  Future<int> generateDueRecurringIncome({DateTime? now}) async =>
      throw UnimplementedError();

  @override
  Future<Category> createCategory(NewCategory category) async =>
      throw UnimplementedError();

  @override
  Future<Category> updateCategory(Category category) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteCategory(String id, CategoryDeletion mode) async =>
      throw UnimplementedError();
}

/// The month the tests open on, so nothing here depends on today's date.
const _march = CalendarMonth(2026, 3);

void main() {
  group('SpendingOverviewBloc', () {
    /// Held onto by the test that checks which months were asked for.
    late FakeCategoryRepository repository;

    blocTest<SpendingOverviewBloc, SpendingOverviewState>(
      'emits loading then the watched categories',
      build: () => SpendingOverviewBloc(
        watchCategorySpend: WatchCategorySpend(
          FakeCategoryRepository(initial: const [_groceries, _rent]),
        ),
        initialMonth: _march,
      ),
      act: (bloc) => bloc.add(const SpendingOverviewSubscriptionRequested()),
      expect: () => const <SpendingOverviewState>[
        SpendingOverviewState(
          month: _march,
          status: SpendingOverviewStatus.loading,
        ),
        SpendingOverviewState(
          month: _march,
          status: SpendingOverviewStatus.success,
          categories: [_groceries, _rent],
        ),
      ],
      verify: (bloc) => expect(bloc.state.totalScaled, 124235),
    );

    blocTest<SpendingOverviewBloc, SpendingOverviewState>(
      'emits failure when the stream errors',
      build: () => SpendingOverviewBloc(
        watchCategorySpend: WatchCategorySpend(_FailingRepository()),
        initialMonth: _march,
      ),
      act: (bloc) => bloc.add(const SpendingOverviewSubscriptionRequested()),
      expect: () => const <SpendingOverviewState>[
        SpendingOverviewState(
          month: _march,
          status: SpendingOverviewStatus.loading,
        ),
        SpendingOverviewState(
          month: _march,
          status: SpendingOverviewStatus.failure,
        ),
      ],
    );

    test('opens on the month happening now', () {
      final bloc = SpendingOverviewBloc(
        watchCategorySpend: WatchCategorySpend(FakeCategoryRepository()),
      );

      expect(bloc.state.month, CalendarMonth.now());
    });

    blocTest<SpendingOverviewBloc, SpendingOverviewState>(
      're-reads both totals for the month it is moved to',
      build: () {
        repository = FakeCategoryRepository(initial: const [_groceries]);
        return SpendingOverviewBloc(
          watchCategorySpend: WatchCategorySpend(repository),
          watchNetTotal: WatchNetTotal(repository),
          initialMonth: _march,
        );
      },
      act: (bloc) async {
        bloc
          ..add(const SpendingOverviewSubscriptionRequested())
          ..add(const SpendingOverviewNetTotalRequested());
        // Let the first subscriptions settle, so what follows is the move and
        // not the opening read.
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SpendingOverviewMonthChanged(CalendarMonth(2026, 2)));
      },
      verify: (bloc) {
        expect(bloc.state.month, const CalendarMonth(2026, 2));
        // Once for March on the way in, once for February on the way back.
        expect(repository.requestedMonths, [
          _march,
          const CalendarMonth(2026, 2),
        ]);
      },
    );

    blocTest<SpendingOverviewBloc, SpendingOverviewState>(
      'keeps the grid up while another month loads',
      build: () => SpendingOverviewBloc(
        watchCategorySpend: WatchCategorySpend(
          FakeCategoryRepository(initial: const [_groceries]),
        ),
        initialMonth: _march,
      ),
      act: (bloc) async {
        bloc.add(const SpendingOverviewSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const SpendingOverviewMonthChanged(CalendarMonth(2026, 2)));
      },
      // No loading in the tail: a spinner over a grid that is about to
      // repopulate reads as the page breaking rather than as it working.
      expect: () => const <SpendingOverviewState>[
        SpendingOverviewState(
          month: _march,
          status: SpendingOverviewStatus.loading,
        ),
        SpendingOverviewState(
          month: _march,
          status: SpendingOverviewStatus.success,
          categories: [_groceries],
        ),
        SpendingOverviewState(
          month: CalendarMonth(2026, 2),
          status: SpendingOverviewStatus.success,
          categories: [_groceries],
        ),
      ],
    );

    blocTest<SpendingOverviewBloc, SpendingOverviewState>(
      'ignores a move to the month already showing',
      build: () => SpendingOverviewBloc(
        watchCategorySpend: WatchCategorySpend(FakeCategoryRepository()),
        initialMonth: _march,
      ),
      act: (bloc) => bloc.add(const SpendingOverviewMonthChanged(_march)),
      expect: () => const <SpendingOverviewState>[],
    );

    test('totalScaled is zero with no categories', () {
      expect(const SpendingOverviewState(month: _march).totalScaled, 0);
    });
  });
}
