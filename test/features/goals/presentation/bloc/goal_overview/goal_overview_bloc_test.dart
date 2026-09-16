import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/usecases/clear_goal.dart';
import 'package:my_pnl/features/goals/domain/usecases/watch_goal.dart';
import 'package:my_pnl/features/goals/presentation/bloc/goal_overview/goal_overview_bloc.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_monthly_pnl.dart';

import '../../../../../helpers/helpers.dart';

const _march = MonthlyPnl(year: 2026, month: 3, netScaled: 200000);
const _april = MonthlyPnl(year: 2026, month: 4, netScaled: -40000);
const _may = MonthlyPnl(year: 2026, month: 5, netScaled: 100000);

const _goal = SavingsGoal(id: 'goal-1', targetAmountScaled: 500000);

/// Serves a fixed set of months. Only the one method the bloc calls is real —
/// the rest of the ledger has its own tests.
class _StubTransactions implements TransactionRepository {
  _StubTransactions(List<MonthlyPnl> months) : _months = Stream.value(months);

  _StubTransactions.failing() : _months = Stream.error(Exception('no ledger'));

  final Stream<List<MonthlyPnl>> _months;

  @override
  Stream<List<MonthlyPnl>> watchMonthlyPnl() => _months;

  @override
  Stream<int> watchNetTotal({CalendarMonth? month}) =>
      throw UnimplementedError();

  @override
  Stream<List<LedgerEntry>> watchAllEntries({CalendarMonth? month}) =>
      throw UnimplementedError();

  @override
  Stream<List<SpendEntry>> watchCategoryHistory(
    String categoryId, {
    CalendarMonth? month,
  }) => throw UnimplementedError();

  @override
  Future<void> recordSpend({
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) async => throw UnimplementedError();

  @override
  Future<void> updateSpend({
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteSpend(String id) async => throw UnimplementedError();

  @override
  Future<int> normalizeAmountSigns() async => throw UnimplementedError();
}

void main() {
  group('GoalOverviewBloc', () {
    late FakeGoalRepository goals;

    setUp(() => goals = FakeGoalRepository());
    tearDown(() => goals.close());

    GoalOverviewBloc build({
      List<MonthlyPnl> months = const [_may, _april, _march],
    }) => GoalOverviewBloc(
      watchMonthlyPnl: WatchMonthlyPnl(_StubTransactions(months)),
      watchGoal: WatchGoal(goals),
      clearGoal: ClearGoal(goals),
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'adds up the positive months and leaves the negative one out',
      build: build,
      act: (bloc) => bloc.add(const GoalOverviewSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.status, GoalOverviewStatus.success);
        expect(bloc.state.positiveMonths, [_may, _march]);
        expect(bloc.state.negativeMonths, [_april]);
        expect(bloc.state.savedScaled, 300000);
        expect(bloc.state.lostScaled, -40000);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'reports failure when the months cannot be read',
      build: () => GoalOverviewBloc(
        watchMonthlyPnl: WatchMonthlyPnl(_StubTransactions.failing()),
        watchGoal: WatchGoal(goals),
        clearGoal: ClearGoal(goals),
      ),
      act: (bloc) => bloc.add(const GoalOverviewSubscriptionRequested()),
      verify: (bloc) => expect(bloc.state.status, GoalOverviewStatus.failure),
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'has no progress until a goal is set',
      build: build,
      act: (bloc) => bloc
        ..add(const GoalOverviewSubscriptionRequested())
        ..add(const GoalTargetSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.hasGoal, isFalse);
        expect(bloc.state.progress, 0);
        expect(bloc.state.remainingScaled, 0);
        expect(bloc.state.isReached, isFalse);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'measures the saved total against the goal',
      build: () {
        goals = FakeGoalRepository(initial: _goal);
        return build();
      },
      act: (bloc) => bloc
        ..add(const GoalOverviewSubscriptionRequested())
        ..add(const GoalTargetSubscriptionRequested()),
      verify: (bloc) {
        // 3000 saved of 5000.
        expect(bloc.state.progress, 0.6);
        expect(bloc.state.progressPercent, 60);
        expect(bloc.state.remainingScaled, 200000);
        expect(bloc.state.isReached, isFalse);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'caps a passed goal at complete',
      build: () {
        goals = FakeGoalRepository(
          initial: const SavingsGoal(id: 'goal-1', targetAmountScaled: 100000),
        );
        return build();
      },
      act: (bloc) => bloc
        ..add(const GoalOverviewSubscriptionRequested())
        ..add(const GoalTargetSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.progress, 1);
        expect(bloc.state.progressPercent, 100);
        expect(bloc.state.remainingScaled, 0);
        expect(bloc.state.isReached, isTrue);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'picks up a goal set while the page is open',
      build: build,
      act: (bloc) async {
        bloc
          ..add(const GoalOverviewSubscriptionRequested())
          ..add(const GoalTargetSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        await goals.saveGoal(targetAmountScaled: 500000);
      },
      verify: (bloc) => expect(bloc.state.progressPercent, 60),
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'clearing drops the target and keeps the months',
      build: () {
        goals = FakeGoalRepository(initial: _goal);
        return build();
      },
      act: (bloc) async {
        bloc
          ..add(const GoalOverviewSubscriptionRequested())
          ..add(const GoalTargetSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GoalCleared());
      },
      verify: (bloc) {
        expect(bloc.state.hasGoal, isFalse);
        expect(bloc.state.savedScaled, 300000);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'projects five percent over ten years to start with',
      build: build,
      act: (bloc) => bloc.add(const GoalOverviewSubscriptionRequested()),
      verify: (bloc) {
        expect(bloc.state.projection.annualPercent, 5);
        expect(bloc.state.projection.years, 10);
        // 3000 saved earns 1,886.68 over ten years, ending on 4,886.68 — and a
        // day at that point earns 65 cents.
        expect(bloc.state.longRunProfitScaled, 188668);
        expect(bloc.state.totalLaterScaled, 488668);
        expect(bloc.state.dailyProfitLaterScaled, 65);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'reprojects when the reader moves the rate',
      build: build,
      act: (bloc) => bloc
        ..add(const GoalOverviewSubscriptionRequested())
        ..add(const GoalReturnRateChanged(20)),
      verify: (bloc) {
        expect(bloc.state.projection.annualPercent, 20);
        expect(
          bloc.state.projection.years,
          10,
          reason: 'the years are left be',
        );
        expect(bloc.state.dailyProfitLaterScaled, 928);
        expect(bloc.state.longRunProfitScaled, 1557521);
        expect(
          bloc.state.savedScaled,
          300000,
          reason: 'the total is untouched',
        );
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'reprojects when the reader moves the years',
      build: build,
      act: (bloc) => bloc
        ..add(const GoalOverviewSubscriptionRequested())
        ..add(const GoalProjectionYearsChanged(1)),
      verify: (bloc) {
        expect(bloc.state.projection.years, 1);
        expect(
          bloc.state.projection.annualPercent,
          5,
          reason: 'rate untouched',
        );
        // One year at 5% is the plain percentage...
        expect(bloc.state.longRunProfitScaled, 15000);
        // ...and a day at the end of it earns 42 cents rather than the 65 of a
        // day ten years in, because far less has compounded by then.
        expect(bloc.state.dailyProfitLaterScaled, 42);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'holds figures off the ends of the sliders in range',
      build: build,
      act: (bloc) => bloc
        ..add(const GoalOverviewSubscriptionRequested())
        ..add(const GoalReturnRateChanged(99))
        ..add(const GoalProjectionYearsChanged(0)),
      verify: (bloc) {
        expect(bloc.state.projection.annualPercent, 20);
        expect(bloc.state.projection.years, 1);
      },
    );

    blocTest<GoalOverviewBloc, GoalOverviewState>(
      'reports a failed clear',
      build: () {
        goals = FakeGoalRepository(initial: _goal)
          ..writeError = Exception('offline');
        return build();
      },
      act: (bloc) async {
        bloc
          ..add(const GoalOverviewSubscriptionRequested())
          ..add(const GoalTargetSubscriptionRequested());
        await Future<void>.delayed(Duration.zero);
        bloc.add(const GoalCleared());
      },
      verify: (bloc) {
        expect(bloc.state.errorMessage, 'Could not remove your goal');
        expect(bloc.state.hasGoal, isTrue, reason: 'nothing was removed');
      },
    );
  });
}
