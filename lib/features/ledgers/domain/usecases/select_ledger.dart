import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Switches which ledger the app reads and writes.
class SelectLedger {
  const SelectLedger(this._repository);

  final LedgerRepository _repository;

  Future<void> call(String ledgerId) => _repository.select(ledgerId);
}
