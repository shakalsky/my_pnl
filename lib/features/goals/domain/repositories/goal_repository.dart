import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';

/// Raised when a goal cannot be saved for a reason worth showing.
class GoalFailure implements Exception {
  const GoalFailure(this.message);

  final String message;

  @override
  String toString() => 'GoalFailure: $message';
}

abstract interface class GoalRepository {
  /// The user's savings goal, or null when none is set, re-emitted as it
  /// changes.
  Stream<SavingsGoal?> watchGoal();

  /// Sets the goal, replacing whatever it was.
  ///
  /// There is one goal per user, so this edits the existing row rather than
  /// adding a second — the page measures against a single figure, and two rows
  /// would make "the goal" ambiguous.
  Future<SavingsGoal> saveGoal(int targetAmountScaled);

  /// Removes the goal.
  ///
  /// A soft delete: the row is tombstoned rather than dropped, because a hard
  /// delete is invisible to sync — a peer cannot tell "deleted" from "not
  /// received yet".
  Future<void> clearGoal();
}
