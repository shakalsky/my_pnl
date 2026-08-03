import 'package:my_pnl/features/currencies/domain/entities/currency.dart';
import 'package:my_pnl/features/currencies/domain/repositories/currency_repository.dart';

/// Streams the user's currencies.
class WatchCurrencies {
  const WatchCurrencies(this._repository);

  final CurrencyRepository _repository;

  Stream<List<Currency>> call() => _repository.watchCurrencies();
}
