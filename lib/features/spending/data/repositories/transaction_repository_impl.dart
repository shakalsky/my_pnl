import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/core/streams/switch_latest.dart';
import 'package:my_pnl/features/spending/data/datasources/transaction_local_data_source.dart';
import 'package:my_pnl/features/spending/domain/entities/calendar_month.dart';
import 'package:my_pnl/features/spending/domain/entities/ledger_entry.dart';
import 'package:my_pnl/features/spending/domain/entities/monthly_pnl.dart';
import 'package:my_pnl/features/spending/domain/entities/spend_entry.dart';
import 'package:my_pnl/features/spending/domain/repositories/transaction_repository.dart';

/// Applies the two scopes so callers never have to think about either.
///
/// Reads get the ledger, which is what puts a partner's spending in the same
/// totals. Writes get the owner as well, which is what keeps that partner from
/// rewriting them.
class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl({
    required TransactionLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
    required LedgerScope ledgerScope,
  }) : _local = localDataSource,
       _owner = sessionOwner,
       _ledger = ledgerScope;

  final TransactionLocalDataSource _local;
  final SessionOwner _owner;
  final LedgerScope _ledger;

  @override
  Future<void> recordSpend({
    required String categoryId,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) {
    return _local.recordSpend(
      ownerId: _owner.id,
      ledgerId: _ledger.id,
      categoryId: categoryId,
      amountScaled: amountScaled,
      occurredAt: occurredAt,
      note: note,
    );
  }

  @override
  Future<void> updateSpend({
    required String id,
    required int amountScaled,
    DateTime? occurredAt,
    String? note,
  }) {
    return _local.updateSpend(
      ownerId: _owner.id,
      id: id,
      amountScaled: amountScaled,
      occurredAt: occurredAt,
      note: note,
    );
  }

  @override
  Future<void> deleteSpend(String id) =>
      _local.deleteSpend(ownerId: _owner.id, id: id);

  // Every read below follows `_ledger.changes`, so a switch re-runs it under the
  // page that is already watching. See `switchLatest`.
  @override
  Stream<List<LedgerEntry>> watchAllEntries() => switchLatest(
    _ledger.changes,
    (ledgerId) =>
        _local.watchAllEntries(ledgerId: ledgerId, viewerId: _owner.id),
  );

  @override
  Stream<int> watchNetTotal({CalendarMonth? month}) => switchLatest(
    _ledger.changes,
    (ledgerId) => _local.watchNetTotal(ledgerId, month: month),
  );

  @override
  Stream<List<MonthlyPnl>> watchMonthlyPnl() => switchLatest(
    _ledger.changes,
    _local.watchMonthlyPnl,
  );

  @override
  Future<int> normalizeAmountSigns() => _local.normalizeAmountSigns(_owner.id);

  @override
  Stream<List<SpendEntry>> watchCategoryHistory(String categoryId) {
    return switchLatest(
      _ledger.changes,
      (ledgerId) => _local.watchCategoryHistory(
        ledgerId: ledgerId,
        viewerId: _owner.id,
        categoryId: categoryId,
      ),
    );
  }
}
