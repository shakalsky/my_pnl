import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';

/// Squares a debt up, or puts it back on the books.
///
/// Two named methods rather than one boolean parameter: `settle(id)` at the
/// call site says what is happening, where `call(id, settled: false)` needs
/// reading twice.
class MarkDebtSettled {
  const MarkDebtSettled(this._repository);

  final DebtRepository _repository;

  Future<void> settle(String id) =>
      _repository.setDebtSettled(id: id, settled: true);

  Future<void> reopen(String id) =>
      _repository.setDebtSettled(id: id, settled: false);
}
