import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/usecases/delete_debt.dart';
import 'package:my_pnl/features/debts/domain/usecases/mark_debt_settled.dart';
import 'package:my_pnl/features/debts/domain/usecases/watch_debts.dart';

part 'debt_list_event.dart';
part 'debt_list_state.dart';

/// Drives the debts page.
class DebtListBloc extends Bloc<DebtListEvent, DebtListState> {
  DebtListBloc({
    required WatchDebts watchDebts,
    required DeleteDebt deleteDebt,
    required MarkDebtSettled markDebtSettled,
  }) : _watchDebts = watchDebts,
       _deleteDebt = deleteDebt,
       _markDebtSettled = markDebtSettled,
       super(const DebtListState()) {
    on<DebtListSubscriptionRequested>(
      _onSubscriptionRequested,
      // Restartable: a second request replaces the running subscription
      // instead of leaving two streams feeding the same state.
      transformer: restartable(),
    );
    on<DebtSettleToggled>(_onSettleToggled);
    on<DebtDeleted>(_onDeleted);
  }

  final WatchDebts _watchDebts;
  final DeleteDebt _deleteDebt;
  final MarkDebtSettled _markDebtSettled;

  Future<void> _onSubscriptionRequested(
    DebtListSubscriptionRequested event,
    Emitter<DebtListState> emit,
  ) async {
    emit(state.copyWith(status: DebtListStatus.loading));

    await emit.forEach<List<Debt>>(
      _watchDebts(),
      onData: (debts) => state.copyWith(
        status: DebtListStatus.success,
        debts: debts,
        clearError: true,
      ),
      onError: (error, stackTrace) {
        log('Watching debts failed', error: error, stackTrace: stackTrace);
        return state.copyWith(status: DebtListStatus.failure);
      },
    );
  }

  Future<void> _onSettleToggled(
    DebtSettleToggled event,
    Emitter<DebtListState> emit,
  ) async {
    try {
      if (event.settled) {
        await _markDebtSettled.settle(event.id);
      } else {
        await _markDebtSettled.reopen(event.id);
      }
      // No emit on success: the watch stream carries the new list, so there is
      // one source of truth for what the page shows.
    } on Object catch (e, s) {
      log('Settling ${event.id} failed', error: e, stackTrace: s);
      emit(state.copyWith(errorMessage: 'Could not update that debt'));
    }
  }

  Future<void> _onDeleted(
    DebtDeleted event,
    Emitter<DebtListState> emit,
  ) async {
    try {
      await _deleteDebt(event.id);
    } on Object catch (e, s) {
      log('Deleting ${event.id} failed', error: e, stackTrace: s);
      emit(state.copyWith(errorMessage: 'Could not remove that debt'));
    }
  }
}
