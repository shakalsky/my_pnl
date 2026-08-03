import 'dart:async';

import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';

/// In-memory stand-in for [GoalRepository].
class FakeGoalRepository implements GoalRepository {
  FakeGoalRepository({SavingsGoal? initial}) : _goal = initial;

  SavingsGoal? _goal;
  final _controller = StreamController<SavingsGoal?>.broadcast();

  /// Set to have any write fail.
  Exception? writeError;

  @override
  Stream<SavingsGoal?> watchGoal() async* {
    yield _goal;
    yield* _controller.stream;
  }

  @override
  Future<SavingsGoal> saveGoal(int targetAmountScaled) async {
    if (writeError case final error?) throw error;

    // Keeps the id when there was already a goal, matching the real upsert.
    final saved = SavingsGoal(
      id: _goal?.id ?? newId(),
      targetAmountScaled: targetAmountScaled,
    );
    _goal = saved;
    _controller.add(saved);
    return saved;
  }

  @override
  Future<void> clearGoal() async {
    if (writeError case final error?) throw error;

    _goal = null;
    _controller.add(null);
  }

  Future<void> close() => _controller.close();
}
