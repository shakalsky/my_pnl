import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/features/spending/data/datasources/transaction_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl({
    required TransactionLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
  }) : _local = localDataSource,
       _owner = sessionOwner;

  final TransactionLocalDataSource _local;
  final SessionOwner _owner;

  @override
  Future<void> recordSpend({
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
  }) {
    return _local.recordSpend(
      ownerId: _owner.id,
      categoryId: categoryId,
      amountScaled: amountScaled,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<void> updateSpend({
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
  }) {
    return _local.updateSpend(
      ownerId: _owner.id,
      id: id,
      amountScaled: amountScaled,
      occurredAt: occurredAt,
    );
  }

  @override
  Future<void> deleteSpend(String id) =>
      _local.deleteSpend(ownerId: _owner.id, id: id);

  @override
  Stream<List<LedgerEntry>> watchAllEntries() =>
      _local.watchAllEntries(_owner.id);

  @override
  Stream<int> watchNetTotal({CalendarMonth? month}) =>
      _local.watchNetTotal(_owner.id, month: month);

  @override
  Stream<List<MonthlyPnl>> watchMonthlyPnl() =>
      _local.watchMonthlyPnl(_owner.id);

  @override
  Future<int> normalizeAmountSigns() =>
      _local.normalizeAmountSigns(_owner.id);

  @override
  Stream<List<SpendEntry>> watchCategoryHistory(String categoryId) {
    return _local.watchCategoryHistory(
      ownerId: _owner.id,
      categoryId: categoryId,
    );
  }
}
