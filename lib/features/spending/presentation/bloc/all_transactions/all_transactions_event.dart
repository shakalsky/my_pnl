part of 'all_transactions_bloc.dart';

sealed class AllTransactionsEvent extends Equatable {
  const AllTransactionsEvent();

  @override
  List<Object?> get props => [];
}

final class AllTransactionsSubscriptionRequested extends AllTransactionsEvent {
  const AllTransactionsSubscriptionRequested();
}

final class AllTransactionsEntryDeleted extends AllTransactionsEvent {
  const AllTransactionsEntryDeleted(this.entryId);

  final String entryId;

  @override
  List<Object?> get props => [entryId];
}
