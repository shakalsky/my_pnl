import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/features/debts/data/datasources/debt_local_data_source.dart';
import 'package:my_pnl/features/debts/domain/entities/debt.dart';
import 'package:my_pnl/features/debts/domain/repositories/debt_repository.dart';

class DebtRepositoryImpl implements DebtRepository {
  const DebtRepositoryImpl({
    required DebtLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
  }) : _local = localDataSource,
       _owner = sessionOwner;

  final DebtLocalDataSource _local;
  final SessionOwner _owner;

  @override
  Stream<List<Debt>> watchDebts() => _local.watchDebts(_owner.id);

  @override
  Future<Debt> createDebt(NewDebt debt) =>
      _local.createDebt(debt, _owner.id);

  @override
  Future<Debt> updateDebt(Debt debt) => _local.updateDebt(debt, _owner.id);

  @override
  Future<void> deleteDebt(String id) =>
      _local.deleteDebt(ownerId: _owner.id, id: id);

  @override
  Future<void> setDebtSettled({required String id, required bool settled}) =>
      _local.setDebtSettled(ownerId: _owner.id, id: id, settled: settled);
}
