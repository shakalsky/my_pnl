import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Creates a family account with an invite code to hand to a partner.
class CreateFamilyLedger {
  const CreateFamilyLedger(this._repository);

  final LedgerRepository _repository;

  Future<Ledger> call(String name) => _repository.createFamilyLedger(name);
}
