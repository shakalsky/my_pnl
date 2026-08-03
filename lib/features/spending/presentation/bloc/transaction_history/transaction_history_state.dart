part of 'transaction_history_bloc.dart';

enum TransactionHistoryStatus { initial, loading, success, failure }

final class TransactionHistoryState extends Equatable {
  const TransactionHistoryState({
    required this.category,
    this.status = TransactionHistoryStatus.initial,
    this.entries = const [],
    this.errorMessage,
  });

  final Category category;
  final TransactionHistoryStatus status;
  final List<SpendEntry> entries;

  /// A failed delete. Kept apart from [status] so a transient error shows as a
  /// message over the list rather than replacing it with an error screen.
  final String? errorMessage;

  int get totalScaled =>
      entries.fold(0, (sum, entry) => sum + entry.amountScaled);

  TransactionHistoryState copyWith({
    TransactionHistoryStatus? status,
    List<SpendEntry>? entries,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TransactionHistoryState(
      category: category,
      status: status ?? this.status,
      entries: entries ?? this.entries,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [category, status, entries, errorMessage];
}
