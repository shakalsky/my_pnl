import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/amount_parse.dart';
import 'package:my_pnl/features/goals/domain/entities/savings_goal.dart';
import 'package:my_pnl/features/goals/domain/repositories/goal_repository.dart';
import 'package:my_pnl/features/goals/domain/usecases/save_goal.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'goal_form_event.dart';
part 'goal_form_state.dart';

/// Drives the modal that sets how much to save up.
class GoalFormBloc extends Bloc<GoalFormEvent, GoalFormState> {
  GoalFormBloc({required SaveGoal saveGoal, SavingsGoal? initial})
    : _saveGoal = saveGoal,
      super(
        GoalFormState(
          isEditing: initial != null,
          amount: initial == null
              ? ''
              : formatAmountInput(initial.targetAmountScaled),
        ),
      ) {
    on<GoalAmountChanged>(
      (event, emit) =>
          emit(state.copyWith(amount: event.amount, clearError: true)),
    );
    on<GoalFormSubmitted>(_onSubmitted);
  }

  final SaveGoal _saveGoal;

  Future<void> _onSubmitted(
    GoalFormSubmitted event,
    Emitter<GoalFormState> emit,
  ) async {
    final amount = state.amountScaled;
    if (!state.isValid || amount == null || state.isSubmitting) return;

    emit(state.copyWith(status: GoalFormStatus.submitting, clearError: true));

    try {
      await _saveGoal(amount);
      emit(state.copyWith(status: GoalFormStatus.success));
    } on GoalFailure catch (e) {
      // Worth naming, and the form stays filled in so it can be corrected.
      emit(
        state.copyWith(
          status: GoalFormStatus.failure,
          errorMessage: e.message,
        ),
      );
      emit(state.copyWith(status: GoalFormStatus.editing));
    } on Object {
      emit(
        state.copyWith(
          status: GoalFormStatus.failure,
          errorMessage: t.goal.saveFailed,
        ),
      );
      emit(state.copyWith(status: GoalFormStatus.editing));
    }
  }
}
