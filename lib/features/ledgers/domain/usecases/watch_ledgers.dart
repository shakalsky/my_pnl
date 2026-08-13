import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Streams every ledger the reader belongs to, re-emitted as memberships
/// arrive.
class WatchLedgers {
  const WatchLedgers(this._repository);

  final LedgerRepository _repository;

  Stream<List<Ledger>> call() => _repository.watchLedgers();
}
