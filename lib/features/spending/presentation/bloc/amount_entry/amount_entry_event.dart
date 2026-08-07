part of 'amount_entry_bloc.dart';

sealed class AmountEntryEvent extends Equatable {
  const AmountEntryEvent();

  @override
  List<Object?> get props => [];
}

final class AmountEntryChanged extends AmountEntryEvent {
  const AmountEntryChanged(this.input);

  /// Raw text, exactly as typed.
  final String input;

  @override
  List<Object?> get props => [input];
}

final class AmountEntryNoteChanged extends AmountEntryEvent {
  const AmountEntryNoteChanged(this.note);

  /// Raw text, exactly as typed.
  final String note;

  @override
  List<Object?> get props => [note];
}

final class AmountEntryDateChanged extends AmountEntryEvent {
  const AmountEntryDateChanged(this.occurredAt);

  /// When the entry happened, in the reader's own zone — which is the zone the
  /// date they picked means something in. The bloc converts it to UTC.
  final DateTime occurredAt;

  @override
  List<Object?> get props => [occurredAt];
}

final class AmountEntrySubmitted extends AmountEntryEvent {
  const AmountEntrySubmitted();
}
