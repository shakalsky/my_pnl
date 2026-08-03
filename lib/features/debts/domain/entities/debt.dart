import 'package:equatable/equatable.dart';

/// Which way a debt points.
enum DebtDirection {
  /// Someone owes the user money.
  owedToMe('owed_to_me'),

  /// The user owes someone money.
  owedByMe('owed_by_me');

  const DebtDirection(this.storage);

  /// The value written to the database.
  ///
  /// Spelt out rather than taken from [name] so renaming the Dart constant
  /// cannot silently orphan every stored row.
  final String storage;

  /// Reads a stored value, falling back to [owedToMe] for anything
  /// unrecognised — a row from a newer client is better shown on one side of
  /// the list than dropped from it.
  static DebtDirection fromStorage(String? value) =>
      value == owedByMe.storage ? owedByMe : owedToMe;
}

/// Money owed, in either direction.
///
/// Separate from the ledger on purpose: lending someone cash does not change
/// what the user is worth, so a debt never appears in the spending or income
/// totals. Settling one is a fact about the debt, not a transaction.
class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.counterparty,
    required this.direction,
    required this.amountScaled,
    this.note,
    this.dueAt,
    this.settledAt,
  });

  final String id;

  /// The person or company on the other side.
  final String counterparty;

  final DebtDirection direction;

  /// Magnitude, scaled by `amountScale`, always positive. Which way the money
  /// points is [direction]'s job.
  final int amountScaled;

  /// What the debt is for. Optional.
  final String? note;

  /// When repayment is expected. Null means no agreed date.
  final DateTime? dueAt;

  /// When the debt was squared up. Null means it is still open.
  final DateTime? settledAt;

  bool get isSettled => settledAt != null;

  bool get isOwedToMe => direction == DebtDirection.owedToMe;

  /// Signed so a mixed list sums to the user's net position: money coming in
  /// counts positive, money going out negative.
  int get signedAmountScaled => isOwedToMe ? amountScaled : -amountScaled;

  /// Whether repayment is past due as of [now]. Settled debts never are.
  bool isOverdue(DateTime now) =>
      !isSettled && dueAt != null && dueAt!.isBefore(now);

  Debt copyWith({
    String? counterparty,
    DebtDirection? direction,
    int? amountScaled,
    String? note,
    DateTime? dueAt,
    DateTime? settledAt,
    bool clearNote = false,
    bool clearDueAt = false,
    bool clearSettledAt = false,
  }) {
    return Debt(
      id: id,
      counterparty: counterparty ?? this.counterparty,
      direction: direction ?? this.direction,
      amountScaled: amountScaled ?? this.amountScaled,
      note: clearNote ? null : note ?? this.note,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      settledAt: clearSettledAt ? null : settledAt ?? this.settledAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    counterparty,
    direction,
    amountScaled,
    note,
    dueAt,
    settledAt,
  ];
}

/// A debt that does not exist yet, so it has no id.
class NewDebt extends Equatable {
  const NewDebt({
    required this.counterparty,
    required this.direction,
    required this.amountScaled,
    this.note,
    this.dueAt,
  });

  final String counterparty;
  final DebtDirection direction;
  final int amountScaled;
  final String? note;
  final DateTime? dueAt;

  @override
  List<Object?> get props => [
    counterparty,
    direction,
    amountScaled,
    note,
    dueAt,
  ];
}
