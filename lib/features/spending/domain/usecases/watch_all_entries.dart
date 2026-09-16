import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Streams every entry the owner has, newest first.
///
/// A month narrows it to what was booked in that month; null is the whole
/// ledger.
class WatchAllEntries {
  const WatchAllEntries(this._repository);

  final TransactionRepository _repository;

  Stream<List<LedgerEntry>> call({CalendarMonth? month}) =>
      _repository.watchAllEntries(month: month);
}
