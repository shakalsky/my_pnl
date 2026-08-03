part of 'all_transactions_bloc.dart';

enum AllTransactionsStatus { initial, loading, success, failure }

final class AllTransactionsState extends Equatable {
  const AllTransactionsState({
    this.status = AllTransactionsStatus.initial,
    this.entries = const [],
    this.errorMessage,
  });

  final AllTransactionsStatus status;
  final List<LedgerEntry> entries;

  /// A failed delete. Separate from [status] so a transient error shows over
  /// the list rather than replacing it.
  final String? errorMessage;

  /// Income minus spending across the entries shown.
  int get netScaled =>
      entries.fold(0, (sum, item) => sum + item.entry.amountScaled);

  AllTransactionsState copyWith({
    AllTransactionsStatus? status,
    List<LedgerEntry>? entries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AllTransactionsState(
      status: status ?? this.status,
      entries: entries ?? this.entries,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, entries, errorMessage];
}
