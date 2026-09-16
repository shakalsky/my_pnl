import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/usecases/delete_spend.dart';
import 'package:my_pnl/features/spending/domain/usecases/watch_all_entries.dart';
import 'package:my_pnl/i18n/strings.g.dart';

part 'all_transactions_event.dart';
part 'all_transactions_state.dart';

/// Drives the modal listing every entry.
class AllTransactionsBloc
    extends Bloc<AllTransactionsEvent, AllTransactionsState> {
  AllTransactionsBloc({
    required WatchAllEntries watchAllEntries,
    required DeleteSpend deleteSpend,
    CalendarMonth? month,
  }) : _watchAllEntries = watchAllEntries,
       _deleteSpend = deleteSpend,
       _month = month,
       super(const AllTransactionsState()) {
    on<AllTransactionsSubscriptionRequested>(
      _onSubscriptionRequested,
      transformer: restartable(),
    );
    on<AllTransactionsEntryDeleted>(_onEntryDeleted);
  }

  final WatchAllEntries _watchAllEntries;
  final DeleteSpend _deleteSpend;

  /// Which month is listed, or null for the whole ledger.
  ///
  /// Fixed for the life of the sheet: it is the month the overview was showing
  /// when the sheet was opened, and nothing in here changes it.
  final CalendarMonth? _month;

  Future<void> _onSubscriptionRequested(
    AllTransactionsSubscriptionRequested event,
    Emitter<AllTransactionsState> emit,
  ) async {
    emit(state.copyWith(status: AllTransactionsStatus.loading));

    await emit.forEach<List<LedgerEntry>>(
      _watchAllEntries(month: _month),
      onData: (entries) => state.copyWith(
        status: AllTransactionsStatus.success,
        entries: entries,
        clearError: true,
      ),
      onError: (error, stackTrace) {
        log(
          'Watching all entries failed',
          error: error,
          stackTrace: stackTrace,
        );
        return state.copyWith(status: AllTransactionsStatus.failure);
      },
    );
  }

  Future<void> _onEntryDeleted(
    AllTransactionsEntryDeleted event,
    Emitter<AllTransactionsState> emit,
  ) async {
    try {
      await _deleteSpend(event.entryId);
      // No emit on success: the watch stream carries the new list, so there is
      // one source of truth for what the modal shows.
    } on Object catch (e, s) {
      log('Deleting ${event.entryId} failed', error: e, stackTrace: s);
      emit(state.copyWith(errorMessage: t.entries.deleteFailed));
    }
  }
}
