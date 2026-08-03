import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Streams income minus spending, for one month or for all time.
class WatchNetTotal {
  const WatchNetTotal(this._repository);

  final TransactionRepository _repository;

  Stream<int> call({CalendarMonth? month}) =>
      _repository.watchNetTotal(month: month);
}
