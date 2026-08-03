import 'package:my_pnl/core/session/session_owner.dart';
import 'package:my_pnl/features/currencies/data/datasources/currency_local_data_source.dart';
import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

class CurrencyRepositoryImpl implements CurrencyRepository {
  const CurrencyRepositoryImpl({
    required CurrencyLocalDataSource localDataSource,
    required SessionOwner sessionOwner,
  }) : _local = localDataSource,
       _owner = sessionOwner;

  final CurrencyLocalDataSource _local;
  final SessionOwner _owner;

  @override
  Stream<List<Currency>> watchCurrencies() => _local.watchCurrencies(_owner.id);

  @override
  Future<Currency> createCurrency(NewCurrency currency) =>
      _local.createCurrency(currency, _owner.id);

  @override
  Future<Currency> updateCurrency(Currency currency) =>
      _local.updateCurrency(currency, _owner.id);

  @override
  Future<void> deleteCurrency(String id) =>
      _local.deleteCurrency(ownerId: _owner.id, id: id);
}
