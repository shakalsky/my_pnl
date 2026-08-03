import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Streams every entry the owner has, newest first.
class WatchAllEntries {
  const WatchAllEntries(this._repository);

  final TransactionRepository _repository;

  Stream<List<LedgerEntry>> call() => _repository.watchAllEntries();
}
