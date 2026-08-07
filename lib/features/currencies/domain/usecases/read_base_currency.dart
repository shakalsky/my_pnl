import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';

/// The currency amounts are recorded and shown in.
class ReadBaseCurrency {
  const ReadBaseCurrency(this._store);

  final BaseCurrencyStore _store;

  Future<BaseCurrency> call() => _store.read();
}
