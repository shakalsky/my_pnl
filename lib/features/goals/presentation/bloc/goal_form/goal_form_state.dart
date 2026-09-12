part of 'goal_form_bloc.dart';

enum GoalFormStatus { editing, submitting, success, failure }

final class GoalFormState extends Equatable {
  const GoalFormState({
    this.amount = '',
    this.startingAmount = '',
    this.isEditing = false,
    this.status = GoalFormStatus.editing,
    this.errorMessage,
  });

  /// What the user typed. Kept as text so the field never fights the cursor.
  final String amount;

  /// What the user typed for money already put aside. Empty is a valid answer
  /// and means nothing — the field is optional.
  final String startingAmount;

  /// Whether a goal was already set. Only changes the wording — saving replaces
  /// the figure either way.
  final bool isEditing;

  final GoalFormStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == GoalFormStatus.submitting;

  /// The parsed target, or null while the input is not a number.
  int? get amountScaled => parseAmount(amount);

  /// The parsed starting amount. Zero for an empty field, so the figure under
  /// it and the save both read an unanswered optional field as nothing.
  int get startingAmountScaled => parseAmount(startingAmount) ?? 0;

  /// Enough to enable the button. The use case validates properly.
  ///
  /// Only the target can block saving: the starting field is optional, and the
  /// formatters on it cannot produce a figure outside the allowed range.
  bool get isValid => switch (amountScaled) {
    null || <= 0 || > maxGoalAmountScaled => false,
    _ => true,
  };

  GoalFormState copyWith({
    String? amount,
    String? startingAmount,
    GoalFormStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GoalFormState(
      amount: amount ?? this.amount,
      startingAmount: startingAmount ?? this.startingAmount,
      isEditing: isEditing,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    amount,
    startingAmount,
    isEditing,
    status,
    errorMessage,
  ];
}
