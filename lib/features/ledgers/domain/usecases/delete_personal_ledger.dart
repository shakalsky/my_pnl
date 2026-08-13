import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Discards one of the reader's own books, leaving what was in it behind.
class DeletePersonalLedger {
  const DeletePersonalLedger(this._repository);

  final LedgerRepository _repository;

  Future<void> call(String ledgerId) =>
      _repository.deletePersonalLedger(ledgerId);
}
