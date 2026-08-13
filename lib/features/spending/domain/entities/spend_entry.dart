import 'package:equatable/equatable.dart';

/// A single amount booked against a category.
class SpendEntry extends Equatable {
  const SpendEntry({
    required this.id,
    required this.amountScaled,
    required this.occurredAt,
    this.note,
    this.isOwn = true,
    this.authorName,
  });

  final String id;

  /// Scaled by `amountScale`.
  final int amountScaled;

  /// Always UTC. Convert to local only when displaying.
  final DateTime occurredAt;

  final String? note;

  /// Whether the signed-in reader recorded this.
  ///
  /// In a family account both partners' entries are read together, but only the
  /// person who recorded one may change or delete it — the Postgres policy on
  /// `transactions` enforces that, and the UI checks this so it does not offer
  /// an action the server would refuse.
  ///
  /// Defaults to true, which is the answer in a ledger nobody else is in.
  final bool isOwn;

  /// What to call whoever recorded it, when that was not the reader.
  ///
  /// Null on your own entries — in a list where a partner's rows are labelled,
  /// the unlabelled ones being yours needs no second marker — and null on a
  /// partner's entry whose device has not written a name yet.
  final String? authorName;

  @override
  List<Object?> get props => [
    id,
    amountScaled,
    occurredAt,
    note,
    isOwn,
    authorName,
  ];
}
