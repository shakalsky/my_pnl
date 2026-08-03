import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

/// Removes the savings goal.
class ClearGoal {
  const ClearGoal(this._repository);

  final GoalRepository _repository;

  Future<void> call() => _repository.clearGoal();
}
