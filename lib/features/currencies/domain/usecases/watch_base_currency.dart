import 'package:my_pnl/core/money/base_currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/base_currency_store.dart';

/// The base currency, re-emitted whenever the reader changes it.
class WatchBaseCurrency {
  const WatchBaseCurrency(this._store);

  final BaseCurrencyStore _store;

  Stream<BaseCurrency> call() => _store.watch();
}
