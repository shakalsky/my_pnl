import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Removes an entry from a category.
class DeleteSpend {
  const DeleteSpend(this._repository);

  final TransactionRepository _repository;

  Future<void> call(String id) => _repository.deleteSpend(id);
}
