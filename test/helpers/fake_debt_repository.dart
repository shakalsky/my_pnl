import 'dart:async';

import 'package:my_pnl/database/database.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';

/// In-memory stand-in for [DebtRepository].
///
/// Widget and bloc tests depend on the domain interface, so none of them need a
/// database. The drift queries are covered directly.
class FakeDebtRepository implements DebtRepository {
  FakeDebtRepository({List<Debt> initial = const []})
    : _debts = List.of(initial);

  final List<Debt> _debts;
  final _controller = StreamController<List<Debt>>.broadcast();

  /// Set to have any write fail.
  Exception? writeError;

  @override
  Stream<List<Debt>> watchDebts() async* {
    yield _ordered();
    yield* _controller.stream;
  }

  @override
  Future<Debt> createDebt(NewDebt debt) async {
    if (writeError case final error?) throw error;

    final created = Debt(
      id: newId(),
      counterparty: debt.counterparty,
      direction: debt.direction,
      amountScaled: debt.amountScaled,
      note: debt.note,
      dueAt: debt.dueAt,
    );
    _debts.add(created);
    _emit();
    return created;
  }

  @override
  Future<Debt> updateDebt(Debt debt) async {
    if (writeError case final error?) throw error;

    _debts[_indexOf(debt.id)] = debt;
    _emit();
    return debt;
  }

  @override
  Future<void> deleteDebt(String id) async {
    if (writeError case final error?) throw error;

    _debts.removeAt(_indexOf(id));
    _emit();
  }

  @override
  Future<void> setDebtSettled({
    required String id,
    required bool settled,
  }) async {
    if (writeError case final error?) throw error;

    final index = _indexOf(id);
    _debts[index] = _debts[index].copyWith(
      settledAt: settled ? DateTime.utc(2026) : null,
      clearSettledAt: !settled,
    );
    _emit();
  }

  int _indexOf(String id) {
    final index = _debts.indexWhere((debt) => debt.id == id);
    if (index == -1) throw StateError('No debt $id');
    return index;
  }

  /// Open debts first, matching the order the real query gives.
  List<Debt> _ordered() {
    final open = _debts.where((debt) => !debt.isSettled);
    final settled = _debts.where((debt) => debt.isSettled);
    return List.unmodifiable([...open, ...settled]);
  }

  void _emit() => _controller.add(_ordered());

  Future<void> close() => _controller.close();
}
