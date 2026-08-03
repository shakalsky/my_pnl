import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

/// Sets how much the user is saving up.
///
/// Validation lives here rather than in the form so the same rule applies to
/// any caller.
class SaveGoal {
  const SaveGoal(this._repository);

  final GoalRepository _repository;

  Future<SavingsGoal> call(int targetAmountScaled) {
    if (targetAmountScaled <= 0) {
      throw const GoalFailure('Enter an amount above zero');
    }

    return _repository.saveGoal(targetAmountScaled);
  }
}
