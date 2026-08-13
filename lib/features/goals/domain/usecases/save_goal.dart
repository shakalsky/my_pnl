import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

/// The largest target a goal can be set to: a trillion whole units.
///
/// Not a rule about money so much as a guard against a stuck key. Past this the
/// figure stops reading as an amount at all, and the progress bar it drives can
/// no longer show any real balance moving.
const int maxGoalAmountScaled = 1000000000000 * amountScale;

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
    if (targetAmountScaled > maxGoalAmountScaled) {
      throw const GoalFailure('Enter an amount up to 1,000,000,000,000');
    }

    return _repository.saveGoal(targetAmountScaled);
  }
}
