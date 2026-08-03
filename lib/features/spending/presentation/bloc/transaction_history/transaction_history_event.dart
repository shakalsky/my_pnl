part of 'transaction_history_bloc.dart';

sealed class TransactionHistoryEvent extends Equatable {
  const TransactionHistoryEvent();

  @override
  List<Object?> get props => [];
}

/// Starts watching the category's entries.
final class TransactionHistorySubscriptionRequested
    extends TransactionHistoryEvent {
  const TransactionHistorySubscriptionRequested();
}

final class TransactionHistoryEntryDeleted extends TransactionHistoryEvent {
  const TransactionHistoryEntryDeleted(this.entryId);

  final String entryId;

  @override
  List<Object?> get props => [entryId];
}
