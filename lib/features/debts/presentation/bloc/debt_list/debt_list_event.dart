part of 'debt_list_bloc.dart';

sealed class DebtListEvent extends Equatable {
  const DebtListEvent();

  @override
  List<Object?> get props => [];
}

final class DebtListSubscriptionRequested extends DebtListEvent {
  const DebtListSubscriptionRequested();
}

final class DebtSettleToggled extends DebtListEvent {
  const DebtSettleToggled({required this.id, required this.settled});

  final String id;

  /// The state being moved to, not the one being left, so the same event
  /// squares a debt up and puts it back.
  final bool settled;

  @override
  List<Object?> get props => [id, settled];
}

final class DebtDeleted extends DebtListEvent {
  const DebtDeleted(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}
