import 'package:my_pnl/features/ledgers/domain/repositories/ledger_repository.dart';

/// Replaces a family account's invite code, revoking every unused invite.
class RotateInviteCode {
  const RotateInviteCode(this._repository);

  final LedgerRepository _repository;

  Future<String> call(String ledgerId) =>
      _repository.rotateInviteCode(ledgerId);
}
