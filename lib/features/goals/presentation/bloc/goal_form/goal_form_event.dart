part of 'goal_form_bloc.dart';

sealed class GoalFormEvent extends Equatable {
  const GoalFormEvent();

  @override
  List<Object?> get props => [];
}

final class GoalAmountChanged extends GoalFormEvent {
  const GoalAmountChanged(this.amount);

  /// Raw text, exactly as typed.
  final String amount;

  @override
  List<Object?> get props => [amount];
}

final class GoalFormSubmitted extends GoalFormEvent {
  const GoalFormSubmitted();
}
