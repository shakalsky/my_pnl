import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';

/// Remembers the currency totals are being read in.
class SaveDisplayCurrency {
  const SaveDisplayCurrency(this._store);

  final DisplayCurrencyStore _store;

  /// Null means the base currency is showing.
  Future<void> call(String? currencyId) => _store.write(currencyId);
}
