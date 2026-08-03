import 'package:my_pnl/features/currencies/domain/repositories/display_currency_store.dart';

/// The currency totals were last read in, by id, or null for the base.
class ReadDisplayCurrency {
  const ReadDisplayCurrency(this._store);

  final DisplayCurrencyStore _store;

  Future<String?> call() => _store.read();
}
