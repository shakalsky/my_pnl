part of 'amount_entry_bloc.dart';

enum AmountEntryStatus { editing, submitting, success, failure }

final class AmountEntryState extends Equatable {
  const AmountEntryState({
    required this.category,
    this.entryId,
    this.input = '',
    this.note = '',
    this.occurredAt,
    this.status = AmountEntryStatus.editing,
  });

  final Category category;

  /// Null when booking a new amount; set to the entry being changed.
  final String? entryId;

  /// When the entry happened, always UTC.
  ///
  /// Null means "whenever this is saved" — the state a new entry opens in, and
  /// what the repository already reads a missing date as. Picking a date fills
  /// it in; nothing sets it back to null, because a chosen date only ever gives
  /// way to another one.
  final DateTime? occurredAt;

  /// What the user typed. Kept as text so the field never fights the cursor.
  final String input;

  /// What the entry is for, in the user's own words. Raw text; blank means the
  /// entry carries no note.
  final String note;

  final AmountEntryStatus status;

  bool get isEditing => entryId != null;

  /// The note to store, or null when the field is blank — storing '' would be
  /// a second way to say the entry has no note.
  String? get noteToStore => note.trim().isEmpty ? null : note.trim();

  /// The parsed amount, or null while the input is not a valid number.
  int? get amountScaled => parseAmount(input);

  bool get isValid => switch (amountScaled) {
    null || 0 => false,
    _ => true,
  };

  bool get isSubmitting => status == AmountEntryStatus.submitting;

  AmountEntryState copyWith({
    String? input,
    String? note,
    DateTime? occurredAt,
    AmountEntryStatus? status,
  }) {
    return AmountEntryState(
      category: category,
      entryId: entryId,
      input: input ?? this.input,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      status: status ?? this.status,
    );
  }

  @override
  List<Object?> get props => [
    category,
    entryId,
    input,
    note,
    occurredAt,
    status,
  ];
}
