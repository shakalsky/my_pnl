import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Creates another book of the reader's own, up to [LedgerLimits.personal].
class CreatePersonalLedger {
  const CreatePersonalLedger(this._repository);

  final LedgerRepository _repository;

  Future<Ledger> call(String name) => _repository.createPersonalLedger(name);
}
