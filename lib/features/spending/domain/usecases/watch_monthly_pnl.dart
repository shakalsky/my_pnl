import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Streams what each month came to, newest first.
class WatchMonthlyPnl {
  const WatchMonthlyPnl(this._repository);

  final TransactionRepository _repository;

  Stream<List<MonthlyPnl>> call() => _repository.watchMonthlyPnl();
}
