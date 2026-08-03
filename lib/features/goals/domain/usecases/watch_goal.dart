import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

/// Streams the user's savings goal, or null when none is set.
class WatchGoal {
  const WatchGoal(this._repository);

  final GoalRepository _repository;

  Stream<SavingsGoal?> call() => _repository.watchGoal();
}
