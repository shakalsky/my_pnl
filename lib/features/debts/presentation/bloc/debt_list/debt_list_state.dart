part of 'debt_list_bloc.dart';

enum DebtListStatus { initial, loading, success, failure }

final class DebtListState extends Equatable {
  const DebtListState({
    this.status = DebtListStatus.initial,
    this.debts = const [],
    this.errorMessage,
  });

  final DebtListStatus status;

  /// Every debt, open and settled, in the order the repository gave them.
  final List<Debt> debts;

  /// A failed settle or delete. Separate from [status] so a transient error
  /// shows over the list rather than replacing it.
  final String? errorMessage;

  /// Open debts someone owes the user.
  List<Debt> get owedToMe => _open(DebtDirection.owedToMe);

  /// Open debts the user owes.
  List<Debt> get owedByMe => _open(DebtDirection.owedByMe);

  List<Debt> get settled =>
      debts.where((debt) => debt.isSettled).toList(growable: false);

  int get owedToMeTotalScaled => _sum(owedToMe);

  int get owedByMeTotalScaled => _sum(owedByMe);

  /// Where the user stands once every open debt is squared up. Settled debts
  /// are left out — they have already been paid, so counting them would show
  /// money that has come and gone.
  int get netTotalScaled => owedToMeTotalScaled - owedByMeTotalScaled;

  bool get hasNoDebts => debts.isEmpty;

  List<Debt> _open(DebtDirection direction) => debts
      .where((debt) => !debt.isSettled && debt.direction == direction)
      .toList(growable: false);

  int _sum(List<Debt> debts) =>
      debts.fold(0, (total, debt) => total + debt.amountScaled);

  DebtListState copyWith({
    DebtListStatus? status,
    List<Debt>? debts,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DebtListState(
      status: status ?? this.status,
      debts: debts ?? this.debts,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, debts, errorMessage];
}
