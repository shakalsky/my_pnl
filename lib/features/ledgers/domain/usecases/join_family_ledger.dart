import 'package:my_pnl/features/ledgers/domain/entities/ledger.dart';
import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Joins the family account an invite code names.
class JoinFamilyLedger {
  const JoinFamilyLedger(this._repository);

  final LedgerRepository _repository;

  Future<Ledger> call(String code) => _repository.joinFamilyLedger(code);
}
