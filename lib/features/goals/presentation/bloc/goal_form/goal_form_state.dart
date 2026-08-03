part of 'goal_form_bloc.dart';

enum GoalFormStatus { editing, submitting, success, failure }

final class GoalFormState extends Equatable {
  const GoalFormState({
    this.amount = '',
    this.isEditing = false,
    this.status = GoalFormStatus.editing,
    this.errorMessage,
  });

  /// What the user typed. Kept as text so the field never fights the cursor.
  final String amount;

  /// Whether a goal was already set. Only changes the wording — saving replaces
  /// the figure either way.
  final bool isEditing;

  final GoalFormStatus status;
  final String? errorMessage;

  bool get isSubmitting => status == GoalFormStatus.submitting;

  /// The parsed target, or null while the input is not a number.
  int? get amountScaled => parseAmount(amount);

  /// Enough to enable the button. The use case validates properly.
  bool get isValid => switch (amountScaled) {
    null || <= 0 => false,
    _ => true,
  };

  GoalFormState copyWith({
    String? amount,
    GoalFormStatus? status,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GoalFormState(
      amount: amount ?? this.amount,
      isEditing: isEditing,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [amount, isEditing, status, errorMessage];
}
