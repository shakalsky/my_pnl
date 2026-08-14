import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/core/money/amount_format.dart';
import 'package:my_pnl/core/money/amount_parse.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';
import 'package:my_pnl/features/debts/domain/usecases/save_debt.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'debt_form_event.dart';
part 'debt_form_state.dart';

/// Drives the add/edit debt modal.
///
/// One modal, one bloc: recording a debt and correcting one differ only in
/// whether the form starts with a debt behind it.
class DebtFormBloc extends Bloc<DebtFormEvent, DebtFormState> {
  DebtFormBloc({
    required SaveDebt saveDebt,
    DebtDirection direction = DebtDirection.owedToMe,
    Debt? initial,
  }) : _saveDebt = saveDebt,
       super(
         DebtFormState(
           debtId: initial?.id,
           counterparty: initial?.counterparty ?? '',
           // An existing debt keeps its own direction; a new one takes it from
           // the button that opened the form.
           direction: initial?.direction ?? direction,
           amount: initial == null
               ? ''
               : formatAmountInput(initial.amountScaled),
           note: initial?.note ?? '',
           dueAt: initial?.dueAt,
           settledAt: initial?.settledAt,
         ),
       ) {
    on<DebtCounterpartyChanged>(
      (event, emit) => emit(
        state.copyWith(counterparty: event.counterparty, clearError: true),
      ),
    );
    on<DebtAmountChanged>(
      (event, emit) =>
          emit(state.copyWith(amount: event.amount, clearError: true)),
    );
    on<DebtNoteChanged>(
      (event, emit) => emit(state.copyWith(note: event.note)),
    );
    on<DebtDirectionChanged>(
      (event, emit) => emit(state.copyWith(direction: event.direction)),
    );
    on<DebtDueDateChanged>(
      (event, emit) => emit(
        state.copyWith(dueAt: event.dueAt, clearDueAt: event.dueAt == null),
      ),
    );
    on<DebtFormSubmitted>(_onSubmitted);
  }

  final SaveDebt _saveDebt;

  Future<void> _onSubmitted(
    DebtFormSubmitted event,
    Emitter<DebtFormState> emit,
  ) async {
    final amount = state.amountScaled;
    if (!state.isValid || amount == null || state.isSubmitting) return;

    emit(state.copyWith(status: DebtFormStatus.submitting, clearError: true));

    try {
      if (state.debtId case final id?) {
        await _saveDebt.update(
          Debt(
            id: id,
            counterparty: state.counterparty,
            direction: state.direction,
            amountScaled: amount,
            note: state.note,
            dueAt: state.dueAt,
            // Carried through: editing an amount must not quietly reopen a
            // debt that was already squared up.
            settledAt: state.settledAt,
          ),
        );
      } else {
        await _saveDebt.create(
          NewDebt(
            counterparty: state.counterparty,
            direction: state.direction,
            amountScaled: amount,
            note: state.note,
            dueAt: state.dueAt,
          ),
        );
      }
      emit(state.copyWith(status: DebtFormStatus.success));
    } on DebtFailure catch (e) {
      // Worth naming, and the form stays filled in so it can be corrected.
      emit(
        state.copyWith(
          status: DebtFormStatus.failure,
          errorMessage: e.message,
        ),
      );
      emit(state.copyWith(status: DebtFormStatus.editing));
    } on Object {
      emit(
        state.copyWith(
          status: DebtFormStatus.failure,
          errorMessage: t.debts.saveFailed,
        ),
      );
      emit(state.copyWith(status: DebtFormStatus.editing));
    }
  }
}
