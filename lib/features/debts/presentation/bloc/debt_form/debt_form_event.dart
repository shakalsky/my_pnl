part of 'debt_form_bloc.dart';

sealed class DebtFormEvent extends Equatable {
  const DebtFormEvent();

  @override
  List<Object?> get props => [];
}

final class DebtCounterpartyChanged extends DebtFormEvent {
  const DebtCounterpartyChanged(this.counterparty);

  final String counterparty;

  @override
  List<Object?> get props => [counterparty];
}

final class DebtAmountChanged extends DebtFormEvent {
  const DebtAmountChanged(this.amount);

  /// Raw text, exactly as typed.
  final String amount;

  @override
  List<Object?> get props => [amount];
}

final class DebtNoteChanged extends DebtFormEvent {
  const DebtNoteChanged(this.note);

  final String note;

  @override
  List<Object?> get props => [note];
}

final class DebtDirectionChanged extends DebtFormEvent {
  const DebtDirectionChanged(this.direction);

  final DebtDirection direction;

  @override
  List<Object?> get props => [direction];
}

final class DebtDueDateChanged extends DebtFormEvent {
  const DebtDueDateChanged(this.dueAt);

  /// Null clears the date, which is how the form says "no agreed date".
  final DateTime? dueAt;

  @override
  List<Object?> get props => [dueAt];
}

final class DebtFormSubmitted extends DebtFormEvent {
  const DebtFormSubmitted();
}
