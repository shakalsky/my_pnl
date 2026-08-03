part of 'debt_form_bloc.dart';

enum DebtFormStatus { editing, submitting, success, failure }

final class DebtFormState extends Equatable {
  const DebtFormState({
    this.debtId,
    this.counterparty = '',
    this.amount = '',
    this.note = '',
    this.direction = DebtDirection.owedToMe,
    this.dueAt,
    this.settledAt,
    this.status = DebtFormStatus.editing,
    this.errorMessage,
  });

  /// Null while adding; set to the debt being changed.
  final String? debtId;

  final String counterparty;

  /// What the user typed for the amount. Kept as text so the field never
  /// fights the cursor.
  final String amount;

  final String note;
  final DebtDirection direction;
  final DateTime? dueAt;

  /// Held only so submitting an edit can put it back unchanged — the form
  /// itself never sets it. Settling goes through `MarkDebtSettled`.
  final DateTime? settledAt;

  final DebtFormStatus status;
  final String? errorMessage;

  bool get isEditing => debtId != null;

  bool get isSubmitting => status == DebtFormStatus.submitting;

  /// The parsed amount, or null while the input is not a number.
  int? get amountScaled => parseAmount(amount);

  bool get isOwedToMe => direction == DebtDirection.owedToMe;

  /// Enough to enable the button. The use case validates properly.
  bool get isValid => switch (amountScaled) {
    null || <= 0 => false,
    _ => counterparty.trim().isNotEmpty,
  };

  DebtFormState copyWith({
    String? counterparty,
    String? amount,
    String? note,
    DebtDirection? direction,
    DateTime? dueAt,
    DebtFormStatus? status,
    String? errorMessage,
    bool clearDueAt = false,
    bool clearError = false,
  }) {
    return DebtFormState(
      debtId: debtId,
      counterparty: counterparty ?? this.counterparty,
      amount: amount ?? this.amount,
      note: note ?? this.note,
      direction: direction ?? this.direction,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      settledAt: settledAt,
      status: status ?? this.status,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    debtId,
    counterparty,
    amount,
    note,
    direction,
    dueAt,
    settledAt,
    status,
    errorMessage,
  ];
}
