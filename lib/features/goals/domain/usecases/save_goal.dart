import 'package:my_pnl/core/money/scales.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/i18n/strings.g.dart';

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

  Future<SavingsGoal> call({
    required int targetAmountScaled,
    int startingAmountScaled = 0,
  }) {
    if (targetAmountScaled <= 0) {
      throw GoalFailure(t.goal.amountAboveZero);
    }
    if (targetAmountScaled > maxGoalAmountScaled) {
      throw GoalFailure(t.goal.amountTooLarge);
    }
    // Zero is allowed here where it is not for the target: starting from
    // nothing is the ordinary case, and it is what an empty field means.
    if (startingAmountScaled < 0) {
      throw GoalFailure(t.goal.startingBelowZero);
    }
    // Capped against the same ceiling rather than against the target. A
    // starting amount past the target is not a mistake — it means the goal is
    // already met, which the page has always been able to show.
    if (startingAmountScaled > maxGoalAmountScaled) {
      throw GoalFailure(t.goal.amountTooLarge);
    }

    return _repository.saveGoal(
      targetAmountScaled: targetAmountScaled,
      startingAmountScaled: startingAmountScaled,
    );
  }
}
