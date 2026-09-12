import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/core/streams/switch_latest.dart';
import 'package:my_pnl/features/goals/data/datasources/goal_local_data_source.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

/// The goal belongs to the ledger: one figure per book.
///
/// In a family account that makes it what the household is saving towards, which
/// is the only reading that agrees with the shared total it is measured against.
class GoalRepositoryImpl implements GoalRepository {
  const GoalRepositoryImpl({
    required GoalLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
    required LedgerScope ledgerScope,
  }) : _local = localDataSource,
       _owner = sessionOwner,
       _ledger = ledgerScope;

  final GoalLocalDataSource _local;
  final SessionOwner _owner;
  final LedgerScope _ledger;

  // Over `_ledger.changes`, so the goal page follows a switch made while it is
  // open. See `switchLatest`.
  @override
  Stream<SavingsGoal?> watchGoal() =>
      switchLatest(_ledger.changes, _local.watchGoal);

  @override
  Future<SavingsGoal> saveGoal({
    required int targetAmountScaled,
    int startingAmountScaled = 0,
  }) => _local.saveGoal(
    ownerId: _owner.id,
    ledgerId: _ledger.id,
    targetAmountScaled: targetAmountScaled,
    startingAmountScaled: startingAmountScaled,
  );

  @override
  Future<void> clearGoal() => _local.clearGoal(_ledger.id);
}
