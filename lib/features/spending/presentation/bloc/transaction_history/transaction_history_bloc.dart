import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/category.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_category_history.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'transaction_history_event.dart';
part 'transaction_history_state.dart';

/// Drives the history modal for one category.
class TransactionHistoryBloc
    extends Bloc<TransactionHistoryEvent, TransactionHistoryState> {
  TransactionHistoryBloc({
    required WatchCategoryHistory watchCategoryHistory,
    required DeleteSpend deleteSpend,
    required Category category,
    CalendarMonth? month,
  }) : _watchCategoryHistory = watchCategoryHistory,
       _deleteSpend = deleteSpend,
       _month = month,
       super(TransactionHistoryState(category: category)) {
    on<TransactionHistorySubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<TransactionHistoryEntryDeleted>(_onEntryDeleted);
  }

  final WatchCategoryHistory _watchCategoryHistory;
  final DeleteSpend _deleteSpend;

  /// Which month is listed, or null for the whole history.
  ///
  /// Fixed for the life of the sheet: it is the month the page behind was
  /// showing when the sheet was opened, and nothing in here changes it.
  final CalendarMonth? _month;

  Future<void> _onEntryDeleted(
    TransactionHistoryEntryDeleted event,
    Emitter<TransactionHistoryState> emit,
  ) async {
    try {
      await _deleteSpend(event.entryId);
      // No emit on success: the watch stream carries the new list, so the
      // list has one source of truth rather than two.
    } on Object {
      emit(state.copyWith(errorMessage: t.entries.deleteFailed));
    }
  }

  Future<void> _onSubscriptionRequested(
    TransactionHistorySubscriptionRequested event,
    Emitter<TransactionHistoryState> emit,
  ) async {
    emit(state.copyWith(status: TransactionHistoryStatus.loading));

    await emit.forEach<List<SpendEntry>>(
      _watchCategoryHistory(state.category.id, month: _month),
      onData: (entries) => state.copyWith(
        status: TransactionHistoryStatus.success,
        entries: entries,
        clearError: true,
      ),
      onError: (error, stackTrace) {
        log(
          'Watching category history failed',
          error: error,
          stackTrace: stackTrace,
        );
        return state.copyWith(status: TransactionHistoryStatus.failure);
      },
    );
  }
}
