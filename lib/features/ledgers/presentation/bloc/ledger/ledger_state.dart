part of 'ledger_bloc.dart';

enum LedgerStatus { initial, loading, success, failure }

final class LedgerState extends Equatable {
  const LedgerState({
    required this.activeId,
    this.status = LedgerStatus.initial,
    this.ledgers = const [],
    this.busy = false,
    this.errorMessage,
  });

  final LedgerStatus status;

  /// Every book the reader belongs to, personal first.
  final List<Ledger> ledgers;

  /// Which of them is open.
  ///
  /// Held rather than derived: the list arrives from a watch stream and the
  /// active id from the session, and on the frames before the first emission
  /// there is an answer to "which one is open" but not yet to "which are there".
  final String activeId;

  /// Whether a create, join or leave is in flight.
  ///
  /// Separate from [status]: those all keep the list on screen while they run,
  /// and only the buttons need to stop responding.
  final bool busy;

  /// A refused action, or a join that worked but has not synced. Separate from
  /// [status] so it shows over the list rather than replacing it.
  final String? errorMessage;

  /// The open book, or null on the frames before the list arrives.
  Ledger? get active {
    for (final ledger in ledgers) {
      if (ledger.id == activeId) return ledger;
    }
    return null;
  }

  /// Whether there is more than one book to switch between.
  bool get canSwitch => ledgers.length > 1;

  /// How many books of the reader's own there are, against the limit.
  int get personalCount => ledgers.where((ledger) => ledger.isPersonal).length;

  /// Whether the reader is already in a family account.
  bool get hasFamily => ledgers.any((ledger) => ledger.isFamily);

  /// Whether another book of their own can be made.
  ///
  /// Answered from the list on screen rather than asked of the database, so the
  /// form can say no before the reader has typed a name. The data source and the
  /// Postgres policy make the same check for real.
  bool get canAddPersonal => personalCount < LedgerLimits.personal;

  /// Whether a family account can be started or joined.
  bool get canAddFamily => !hasFamily;

  LedgerState copyWith({
    LedgerStatus? status,
    List<Ledger>? ledgers,
    String? activeId,
    bool? busy,
    String? errorMessage,
    bool clearError = false,
  }) {
    return LedgerState(
      status: status ?? this.status,
      ledgers: ledgers ?? this.ledgers,
      activeId: activeId ?? this.activeId,
      busy: busy ?? this.busy,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    ledgers,
    activeId,
    busy,
    errorMessage,
  ];
}
