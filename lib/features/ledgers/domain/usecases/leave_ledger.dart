import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Gives up access to a family account, leaving its history behind.
class LeaveLedger {
  const LeaveLedger(this._repository);

  final LedgerRepository _repository;

  Future<void> call(String ledgerId) => _repository.leave(ledgerId);
}
