import 'package:my_pnl/core/session/ledger_scope.dart';
import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/core/streams/switch_latest.dart';
import 'package:my_pnl/features/currencies/data/datasources/currency_local_data_source.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

/// Rates belong to the ledger, so a family account has one set of them.
///
/// The owner id is still stamped on a new row to record who added it, but it
/// scopes nothing: either partner may correct a rate, and a rate only one of
/// them could see would make their totals disagree.
class CurrencyRepositoryImpl implements CurrencyRepository {
  const CurrencyRepositoryImpl({
    required CurrencyLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
    required LedgerScope ledgerScope,
  }) : _local = localDataSource,
       _owner = sessionOwner,
       _ledger = ledgerScope;

  final CurrencyLocalDataSource _local;
  final SessionOwner _owner;
  final LedgerScope _ledger;

  // Over `_ledger.changes`, so a switch re-runs the query under whatever is
  // already reading it. See `switchLatest`.
  @override
  Stream<List<Currency>> watchCurrencies() =>
      switchLatest(_ledger.changes, _local.watchCurrencies);

  @override
  Future<Currency> createCurrency(NewCurrency currency) =>
      _local.createCurrency(
        currency,
        ownerId: _owner.id,
        ledgerId: _ledger.id,
      );

  @override
  Future<Currency> updateCurrency(Currency currency) =>
      _local.updateCurrency(currency, _ledger.id);

  @override
  Future<void> deleteCurrency(String id) =>
      _local.deleteCurrency(ledgerId: _ledger.id, id: id);
}
