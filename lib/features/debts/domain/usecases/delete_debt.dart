import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';

/// Removes a debt.
class DeleteDebt {
  const DeleteDebt(this._repository);

  final DebtRepository _repository;

  Future<void> call(String id) => _repository.deleteDebt(id);
}
