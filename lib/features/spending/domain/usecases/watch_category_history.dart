import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Streams the entries booked against one category, newest first.
class WatchCategoryHistory {
  const WatchCategoryHistory(this._repository);

  final TransactionRepository _repository;

  Stream<List<SpendEntry>> call(String categoryId) =>
      _repository.watchCategoryHistory(categoryId);
}
