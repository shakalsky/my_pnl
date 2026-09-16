import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Streams the entries booked against one category, newest first.
///
/// A month narrows it to what was booked in that month; null is the whole
/// history.
class WatchCategoryHistory {
  const WatchCategoryHistory(this._repository);

  final TransactionRepository _repository;

  Stream<List<SpendEntry>> call(String categoryId, {CalendarMonth? month}) =>
      _repository.watchCategoryHistory(categoryId, month: month);
}
