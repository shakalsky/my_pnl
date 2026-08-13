import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/core/streams/switch_latest.dart';
import 'package:my_pnl/features/debts/data/datasources/debt_local_data_source.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';

/// Debts belong to the ledger, so a family account tracks them together.
///
/// Either partner can settle one — which is most of why keeping them in a shared
/// book is worth anything — so the owner id records who entered it and scopes
/// nothing.
class DebtRepositoryImpl implements DebtRepository {
  const DebtRepositoryImpl({
    required DebtLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
    required LedgerScope ledgerScope,
  }) : _local = localDataSource,
       _owner = sessionOwner,
       _ledger = ledgerScope;

  final DebtLocalDataSource _local;
  final SessionOwner _owner;
  final LedgerScope _ledger;

  // Over `_ledger.changes`, so the list reloads when the reader switches books
  // while the debts page is open. See `switchLatest`.
  @override
  Stream<List<Debt>> watchDebts() =>
      switchLatest(_ledger.changes, _local.watchDebts);

  @override
  Future<Debt> createDebt(NewDebt debt) =>
      _local.createDebt(debt, ownerId: _owner.id, ledgerId: _ledger.id);

  @override
  Future<Debt> updateDebt(Debt debt) => _local.updateDebt(debt, _ledger.id);

  @override
  Future<void> deleteDebt(String id) =>
      _local.deleteDebt(ledgerId: _ledger.id, id: id);

  @override
  Future<void> setDebtSettled({required String id, required bool settled}) =>
      _local.setDebtSettled(ledgerId: _ledger.id, id: id, settled: settled);
}
