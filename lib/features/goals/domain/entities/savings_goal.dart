import 'package:equatable/equatable.dart';

/// How much the user is trying to save up.
///
/// One goal at a time, so the app has a single figure to measure against. No
/// name: the page shows one thing, and a label nobody reads is a column to keep
/// in step for nothing.
class SavingsGoal extends Equatable {
  const SavingsGoal({required this.id, required this.targetAmountScaled});

  final String id;

  /// The figure being saved towards, scaled by `amountScale`. Always positive —
  /// a goal of zero or less is not a goal.
  final int targetAmountScaled;

  /// How far along [savedScaled] is, as a fraction between 0 and 1.
  ///
  /// Clamped, so a goal that has been passed reads as done rather than
  /// overflowing whatever draws it.
  double progressOf(int savedScaled) =>
      (savedScaled / targetAmountScaled).clamp(0, 1);

  /// What is still to go, never below zero.
  int remainingFrom(int savedScaled) {
    final remaining = targetAmountScaled - savedScaled;
    return remaining > 0 ? remaining : 0;
  }

  bool isReachedBy(int savedScaled) => savedScaled >= targetAmountScaled;

  @override
  List<Object?> get props => [id, targetAmountScaled];
}
