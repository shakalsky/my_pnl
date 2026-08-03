import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/features/goals/data/datasources/goal_local_data_source.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

class GoalRepositoryImpl implements GoalRepository {
  const GoalRepositoryImpl({
    required GoalLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
  }) : _local = localDataSource,
       _owner = sessionOwner;

  final GoalLocalDataSource _local;
  final SessionOwner _owner;

  @override
  Stream<SavingsGoal?> watchGoal() => _local.watchGoal(_owner.id);

  @override
  Future<SavingsGoal> saveGoal(int targetAmountScaled) => _local.saveGoal(
    ownerId: _owner.id,
    targetAmountScaled: targetAmountScaled,
  );

  @override
  Future<void> clearGoal() => _local.clearGoal(_owner.id);
}
